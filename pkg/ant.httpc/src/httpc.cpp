#include <Windows.h>
#include <WinInet.h>
#include <lua.hpp>
#include <bee/lua/udata.h>
#include <bee/nonstd/unreachable.h>
#include <bee/thread/simplethread.h>
#include <bee/win/wtf8.h>
#include <bee/error.h>
#include <array>
#include <charconv>
#include <cstring>
#include <cstddef>
#include <memory>
#include <optional>
#include <span>
#include <deque>
#include "channel.h"
#include "memory.h"

extern "C" {
#include <3rd/lua-seri/lua-seri.h>
}

template <size_t N>
static bool zip_wstr(std::array<wchar_t, N> const& wstr, std::array<char, N>& str) {
    for (size_t i = 0; i < N; ++i) {
        wchar_t wc = wstr[i];
        char c = (char)wc;
        if (wc != c) {
            return false;
        }
        str[i] = c;
    }
    return true;
}

template <size_t N>
struct HttpcTaskBuffer {
    void* data() const {
        return (void*)(m_data.data());
    }
    DWORD size() const {
        return m_size;
    }
    void* in_data() {
        return (void*)(m_data.data() + m_size);
    }
    DWORD in_size() {
        return N - m_size;
    }
    void read(DWORD n) {
        m_size += n;
    }
    void write(DWORD n) {
        if (n == m_size) {
            m_size = 0;
            return;
        }
        std::memmove(m_data.data(), m_data.data() + n, m_size - n);
        m_size -= n;
    }
    std::array<std::byte, N> m_data;
    DWORD m_size = 0;
};

struct HttpcDownloadOutput {
    virtual ~HttpcDownloadOutput() {}
    virtual bool init() noexcept { return true; }
    virtual bool finish() noexcept { return true; }
    virtual void completion(lua_State* L) noexcept { }
    virtual std::optional<size_t> write(const void* buf, size_t len) noexcept { return std::nullopt; }
};

struct HttpcDownloadOutputFile: public HttpcDownloadOutput {
    std::wstring file;
    HANDLE tmpFile = INVALID_HANDLE_VALUE;
    HttpcDownloadOutputFile(bee::zstring_view file) noexcept
        : file(bee::wtf8::u2w(file))
    {}
    ~HttpcDownloadOutputFile() noexcept {
        if (tmpFile != INVALID_HANDLE_VALUE) {
            CloseHandle(tmpFile);
        }
    }
    bool init() noexcept {
        tmpFile = CreateFileW((file + L".part").c_str(), GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        if (tmpFile == INVALID_HANDLE_VALUE) {
            return false;
        }
        return true;
    }
    bool finish() noexcept {
        CloseHandle(tmpFile);
        tmpFile = INVALID_HANDLE_VALUE;
        if (!MoveFileExW((file + L".part").c_str(), file.c_str(), MOVEFILE_COPY_ALLOWED | MOVEFILE_REPLACE_EXISTING)) {
            return false;
        }
        return true;
    }
    std::optional<size_t> write(const void* buf, size_t len) noexcept {
        DWORD n = 0;
        if (!WriteFile(tmpFile, buf, (DWORD)len, &n, nullptr)) {
            return std::nullopt;
        }
        return (size_t)n;
    }
};

struct HttpcDownloadOutputMemory: public HttpcDownloadOutput {
    MemoryBuilder<1024> builder;
    void completion(lua_State* L) noexcept {
        auto mem = builder.release();
        lua_pushlstring(L, (const char*)mem.data(), mem.size());
        lua_setfield(L, -2, "content");
    }
    std::optional<size_t> write(const void* buf, size_t len) noexcept {
        builder.append((const std::byte*)buf, len);
        return len;
    }
};

struct HttpcTask {
    int64_t id;
    std::wstring url;
    URL_COMPONENTSW comp { sizeof(comp) };
    HINTERNET connect = nullptr;
    HINTERNET request = nullptr;
    uint64_t writtenLength = 0;
    uint64_t contentLength = 0;
    DWORD statusCode = 200;
    HttpcTaskBuffer<4096> buffer;
    bool completion = false;
    std::unique_ptr<HttpcDownloadOutput> output;
    enum class Status {
        Failed,
        Idle,
        Pending,
        Completion,
    };
    HttpcTask(int64_t id, bee::zstring_view url, bee::zstring_view file) noexcept
        : id(id)
        , url(bee::wtf8::u2w(url))
        , output(new HttpcDownloadOutputFile(file))
    {}
    HttpcTask(int64_t id, bee::zstring_view url) noexcept
        : id(id)
        , url(bee::wtf8::u2w(url))
        , output(new HttpcDownloadOutputMemory())
    {}
    ~HttpcTask() noexcept {
        if (connect) {
            InternetCloseHandle(connect);
        }
        if (request) {
            InternetCloseHandle(request);
        }
    }
    bool parseUrl() noexcept {
        comp.dwSchemeLength = 1;
        comp.dwHostNameLength = 1;
        if (!InternetCrackUrlW(url.c_str(), 0, 0, &comp)) {
            return false;
        }
        if (comp.nScheme != INTERNET_SCHEME_HTTP && comp.nScheme != INTERNET_SCHEME_HTTPS) {
            SetLastError(ERROR_INVALID_PARAMETER);
            return false;
        }
        return true;
    }
    template <typename T>
    std::optional<T> queryInfo(DWORD flags) const noexcept {
        T v;
        DWORD size = sizeof(T);
        if (!HttpQueryInfoW(request, flags, &v, &size, nullptr)) {
            return std::nullopt;
        }
        return v;
    }
    bool init(HINTERNET handle) noexcept {
        DeleteUrlCacheEntryW(url.c_str());
        std::wstring host(comp.lpszHostName, comp.dwHostNameLength);
        connect = InternetConnectW(handle, host.c_str(), (INTERNET_PORT)comp.nPort, nullptr, nullptr, INTERNET_SERVICE_HTTP, 0, 0);
        if (!connect) {
            return false;
        }
        DWORD flags = INTERNET_FLAG_IGNORE_REDIRECT_TO_HTTP |
            INTERNET_FLAG_KEEP_CONNECTION |
            INTERNET_FLAG_NO_AUTH |
            INTERNET_FLAG_NO_COOKIES |
            INTERNET_FLAG_NO_UI |
            INTERNET_FLAG_SECURE |
            INTERNET_FLAG_IGNORE_CERT_CN_INVALID |
            INTERNET_FLAG_RELOAD;
        request = InternetOpenUrlW(handle, url.c_str(), nullptr, 0, flags, 0);
        if (!request) {
            return false;
        }
        auto code = queryInfo<DWORD>(HTTP_QUERY_FLAG_NUMBER | HTTP_QUERY_STATUS_CODE);
        if (!code) {
            return false;
        }
        statusCode = *code;
        auto wszContentLength = queryInfo<std::array<wchar_t, 20>>(HTTP_QUERY_CONTENT_LENGTH);
        if (wszContentLength) {
            std::array<char, 20> szContentLength;
            if (zip_wstr(*wszContentLength, szContentLength)) {
                if (auto [p, ec] = std::from_chars(szContentLength.data(), szContentLength.data() + szContentLength.size(), contentLength); ec != std::errc()) {
                    contentLength = 0;
                }
            }
        }
        if (!output->init()) {
            return false;
        }
        return true;
    }
    bool finish() {
        return output->finish();
    }
    Status update() noexcept {
        if (!completion && buffer.in_size() > 0) {
            DWORD read = 0;
            BOOL ok = InternetReadFile(request, buffer.in_data(), buffer.in_size(), &read);
            if (!ok) {
                return Status::Failed;
            }
            if (read == 0) {
                completion = true;
            }
            else {
                buffer.read(read);
            }
        }
        if (buffer.size() != 0) {
            if (auto write = output->write(buffer.data(), buffer.size())) {
                if (*write == 0) {
                    return Status::Idle;
                }
                else {
                    buffer.write((DWORD)*write);
                    writtenLength += *write;
                    if (completion && buffer.size() == 0) {
                        return finish()? Status::Completion: Status::Failed;
                    }
                    return Status::Pending;
                }
            }
            else {
                return Status::Failed;
            }
        }
        if (completion) {
            return finish()? Status::Completion: Status::Failed;
        }
        return Status::Idle;
    }
};

struct HttpcSession {
    bee::thread_handle thread = nullptr;
    MessageChannel request;
    MessageChannel response;
    int64_t taskid = 0;
    HINTERNET handle = nullptr;
    lua_State* L = nullptr;
    bool stop = false;
    std::unique_ptr<HttpcTask> update_tasks;
    
    HttpcSession() noexcept {
    }
    ~HttpcSession() noexcept {
        stop = true;
        bee::thread_wait(thread);
        lua_close(L);
        if (handle) {
            InternetCloseHandle(handle);
        }
    }
    bool init() noexcept {
        handle = InternetOpenW(L"ant-httpc", INTERNET_OPEN_TYPE_PRECONFIG, nullptr, nullptr, 0);
        if (!handle) {
            return false;
        }
        DWORD option = HTTP_PROTOCOL_FLAG_HTTP2;
        InternetSetOptionW(handle, INTERNET_OPTION_ENABLE_HTTP_PROTOCOL, &option, sizeof(option));
        L = luaL_newstate();
        thread = bee::thread_create(+[](void* ud) noexcept {
            ((HttpcSession*)ud)->threadFunc();
        }, this);
        return true;
    }
    void threadFunc() noexcept {
        std::vector<std::unique_ptr<HttpcTask>> init_tasks;
        while (!stop) {
            request.select([&](void* task) {
                init_tasks.emplace_back((HttpcTask*)task);
            });
            if (!update_tasks && !init_tasks.empty()) {
                auto&& task = init_tasks.back();
                if (task->init(handle)) {
                    update_tasks = std::move(task);
                }
                else {
                    sendErrorMessage(task.get());
                }
                init_tasks.pop_back();
            }
            if (update_tasks) {
                switch (update_tasks->update()) {
                case HttpcTask::Status::Idle:
                    break;
                case HttpcTask::Status::Pending:
                    sendProgressMessage(update_tasks.get());
                    break;
                case HttpcTask::Status::Failed:
                    sendErrorMessage(update_tasks.get());
                    update_tasks.reset();
                    break;
                case HttpcTask::Status::Completion:
                    sendCompletionMessage(update_tasks.get());
                    update_tasks.reset();
                    break;
                default:
                    std::unreachable();
                }
            }
            bee::thread_sleep(10);
        }
    }
    void sendErrorMessage(HttpcTask* task) {
        lua_settop(L, 0);
        lua_newtable(L);
        lua_pushinteger(L, task->id);
        lua_setfield(L, -2, "id");
        lua_pushstring(L, "error");
        lua_setfield(L, -2, "type");
        lua_pushstring(L, bee::error::sys_errmsg("download").c_str());
        lua_setfield(L, -2, "errmsg");
        response.push(seri_pack(L, 0, NULL));
    }
    void sendCompletionMessage(HttpcTask* task) {
        lua_settop(L, 0);
        lua_newtable(L);
        lua_pushinteger(L, task->id);
        lua_setfield(L, -2, "id");
        lua_pushstring(L, "completion");
        lua_setfield(L, -2, "type");
        lua_pushinteger(L, task->statusCode);
        lua_setfield(L, -2, "code");
        task->output->completion(L);
        response.push(seri_pack(L, 0, NULL));
    }
    void sendProgressMessage(HttpcTask* task) {
        lua_settop(L, 0);
        lua_newtable(L);
        lua_pushinteger(L, task->id);
        lua_setfield(L, -2, "id");
        lua_pushstring(L, "progress");
        lua_setfield(L, -2, "type");
        lua_pushinteger(L, task->writtenLength);
        lua_setfield(L, -2, "n");
        if (task->contentLength != 0) {
            lua_pushinteger(L, task->contentLength);
            lua_setfield(L, -2, "total");
        }
        response.push(seri_pack(L, 0, NULL));
    }
    void select(SelectHandler handler) {
        response.select(handler);
    }
    std::optional<int64_t> createDownloadTask(bee::zstring_view url, bee::zstring_view file) noexcept {
        int64_t id = ++taskid;
        auto task = std::make_unique<HttpcTask>(id, url, file);
        if (!task->parseUrl()) {
            return std::nullopt;
        }
        request.push(task.release());
        return id;
    }
    std::optional<int64_t> createDownloadTask(bee::zstring_view url) noexcept {
        int64_t id = ++taskid;
        auto task = std::make_unique<HttpcTask>(id, url);
        if (!task->parseUrl()) {
            return std::nullopt;
        }
        request.push(task.release());
        return id;
    }
};

static bee::zstring_view lua_checkstrview(lua_State* L, int idx) {
    size_t sz = 0;
    const char* str = luaL_checklstring(L, idx, &sz);
    return { str, sz };
}

static int session(lua_State* L) {
    auto& s = bee::lua::newudata<HttpcSession>(L);
    if (!s.init()) {
        lua_pushnil(L);
        lua_pushstring(L, bee::error::sys_errmsg("session").c_str());
        return 2;
    }
    return 1;
}

static int download(lua_State* L) {
    auto& s = bee::lua::checkudata<HttpcSession>(L, 1);
    auto url = lua_checkstrview(L, 2);
    if (lua_isnoneornil(L, 3)) {
        if (auto id = s.createDownloadTask(url)) {
            lua_pushinteger(L, *id);
            return 1;
        }
    }
    else {
        auto file = lua_checkstrview(L, 3);
        if (auto id = s.createDownloadTask(url, file)) {
            lua_pushinteger(L, *id);
            return 1;
        }
    }
    lua_pushnil(L);
    lua_pushstring(L, bee::error::sys_errmsg("download").c_str());
    return 2;
}

static int upload(lua_State* L) {
    return luaL_error(L, "unimpl");
}

static int select(lua_State* L) {
    auto& s = bee::lua::checkudata<HttpcSession>(L, 1);
    lua_newtable(L);
    lua_Integer n = 0;
    s.select([&](void* data) {
        seri_unpackptr(L, data);
        lua_seti(L, -2, ++n);
    });
    return 1;
}

extern "C"
int luaopen_httpc(lua_State* L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "session", session },
        { "download", download },
        { "upload", upload },
        { "select", select },
        { NULL, NULL },
    };
    luaL_newlib(L, l);
    return 1;
}

namespace bee::lua {
    template <>
    struct udata<HttpcSession> {
        static inline auto metatable = +[](lua_State*){};
    };
}

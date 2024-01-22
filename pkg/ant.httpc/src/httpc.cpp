#include <Windows.h>
#include <WinInet.h>
#include <lua.hpp>
#include <bee/lua/binding.h>
#include <bee/thread/simplethread.h>
#include <bee/platform/win/unicode.h>
#include <bee/error.h>
#include <array>
#include <charconv>
#include <cstring>
#include <memory>
#include <optional>
#include "channel.h"

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

struct HttpcTask {
    int64_t id;
    std::wstring url;
    std::wstring file;
    URL_COMPONENTSW comp { sizeof(comp) };
    HINTERNET connect = nullptr;
    HINTERNET request = nullptr;
    HANDLE tmpFile = INVALID_HANDLE_VALUE;
    uint64_t writtenLength = 0;
    uint64_t contentLength = 0;
    HttpcTaskBuffer<4096> buffer;
    bool completion = false;
    enum class Status {
        Failed,
        Idle,
        Pending,
        Completion,
    };
    HttpcTask(int64_t id, bee::zstring_view url, bee::zstring_view file) noexcept
        : id(id)
        , url(bee::win::u2w(url))
        , file(bee::win::u2w(file))
    {}
    ~HttpcTask() noexcept {
        if (connect) {
            InternetCloseHandle(connect);
        }
        if (request) {
            InternetCloseHandle(request);
        }
        if (tmpFile != INVALID_HANDLE_VALUE) {
            CloseHandle(tmpFile);
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
        if (!queryInfo<DWORD>(HTTP_QUERY_FLAG_NUMBER | HTTP_QUERY_STATUS_CODE)) {
            return false;
        }
        auto wszContentLength = queryInfo<std::array<wchar_t, 20>>(HTTP_QUERY_CONTENT_LENGTH);
        if (wszContentLength) {
            std::array<char, 20> szContentLength;
            if (zip_wstr(*wszContentLength, szContentLength)) {
                if (auto [p, ec] = std::from_chars(szContentLength.data(), szContentLength.data() + szContentLength.size(), contentLength); ec != std::errc()) {
                    contentLength = 0;
                }
            }
        }
        tmpFile = CreateFileW((file + L".part").c_str(), GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        if (tmpFile == INVALID_HANDLE_VALUE) {
            return false;
        }
        return true;
    }
    bool finish() {
        CloseHandle(tmpFile);
        tmpFile = INVALID_HANDLE_VALUE;
        if (!MoveFileExW((file + L".part").c_str(), file.c_str(), MOVEFILE_COPY_ALLOWED | MOVEFILE_REPLACE_EXISTING)) {
            return false;
        }
        return true;
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
            DWORD write = 0;
            if (!WriteFile(tmpFile, buffer.data(), buffer.size(), &write, nullptr)) {
                return Status::Failed;
            }
            if (write == 0) {
                return Status::Idle;
            }
            else {
                buffer.write(write);
                writtenLength += write;
                if (completion && buffer.size() == 0) {
                    return finish()? Status::Completion: Status::Failed;
                }
                return Status::Pending;
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
    std::vector<std::unique_ptr<HttpcTask>> update_tasks;
    
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
            if (!init_tasks.empty()) {
                for (auto&& task : init_tasks) {
                    if (task->init(handle)) {
                        update_tasks.emplace_back(std::move(task));
                    }
                    else {
                        sendErrorMessage(task.get());
                    }
                }
                init_tasks.clear();
            }
            for (auto it = update_tasks.begin(); it != update_tasks.end();) {
                auto const& task = *it;
                switch (task->update()) {
                case HttpcTask::Status::Idle:
                    ++it;
                    break;
                case HttpcTask::Status::Pending:
                    sendProgressMessage(task.get());
                    ++it;
                    break;
                case HttpcTask::Status::Failed:
                    sendErrorMessage(task.get());
                    it = update_tasks.erase(it);
                    break;
                case HttpcTask::Status::Completion:
                    sendCompletionMessage(task.get());
                    it = update_tasks.erase(it);
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
        lua_pushstring(L, bee::make_syserror("download").c_str());
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
        lua_pushstring(L, bee::make_syserror("session").c_str());
        return 2;
    }
    return 1;
}

static int download(lua_State* L) {
    auto& s = bee::lua::checkudata<HttpcSession>(L, 1);
    auto url = lua_checkstrview(L, 2);
    auto file = lua_checkstrview(L, 3);
    if (auto id = s.createDownloadTask(url, file)) {
        lua_pushinteger(L, *id);
        return 1;
    }
    lua_pushnil(L);
    lua_pushstring(L, bee::make_syserror("download").c_str());
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
        static inline auto name = "HttpcSession";
        static inline auto metatable = +[](lua_State*){};
    };
}

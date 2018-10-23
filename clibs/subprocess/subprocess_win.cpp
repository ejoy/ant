#include "subprocess.h"
#include <Windows.h>
#include <memory>
#include <deque>
#include <assert.h>
#include <fcntl.h>
#include <io.h>

namespace base { namespace win { namespace subprocess {

    struct strbuilder {
        struct node {
            size_t size;
            size_t maxsize;
            wchar_t* data;
            node(size_t maxsize)
                : size(0)
                , maxsize(maxsize)
                , data(new wchar_t[maxsize])
            { }
            ~node() {
                delete[] data;
            }
            wchar_t* release() {
                wchar_t* r = data;
                data = nullptr;
                return r;
            }
            bool append(const wchar_t* str, size_t n) {
                if (size + n > maxsize) {
                    return false;
                }
                memcpy(data + size, str, n * sizeof(wchar_t));
                size += n;
                return true;
            }
            template <class T, size_t n>
            void operator +=(T(&str)[n]) {
                append(str, n - 1);
            }
        };
        strbuilder() : size(0) { }
        void clear() {
            size = 0;
            data.clear();
        }
        bool append(const wchar_t* str, size_t n) {
            if (!data.empty() && data.back().append(str, n)) {
                size += n;
                return true;
            }
            size_t m = 1024;
            while (m < n) {
                m *= 2;
            }
            data.emplace_back(m).append(str, n);
            size += n;
            return true;
        }
        template <class T, size_t n>
        strbuilder& operator +=(T(&str)[n]) {
            append(str, n - 1);
            return *this;
        }
        strbuilder& operator +=(const std::wstring& s) {
            append(s.data(), s.size());
            return *this;
        }
        wchar_t* string() {
            node r(size + 1);
            for (auto& s : data) {
                r.append(s.data, s.size);
            }
            r += L"\0";
            return r.release();
        }
        std::deque<node> data;
        size_t size;
    };

    static std::wstring quote_arg(const std::wstring& source) {
        size_t len = source.size();
        if (len == 0) {
            return L"\"\"";
        }
        if (std::wstring::npos == source.find_first_of(L" \t\"")) {
            return source;
        }
        if (std::wstring::npos == source.find_first_of(L"\"\\")) {
            return L"\"" + source + L"\"";
        }
        std::wstring target;
        target += L'"';
        int quote_hit = 1;
        for (size_t i = len; i > 0; --i) {
            target += source[i - 1];

            if (quote_hit && source[i - 1] == L'\\') {
                target += L'\\';
            }
            else if (source[i - 1] == L'"') {
                quote_hit = 1;
                target += L'\\';
            }
            else {
                quote_hit = 0;
            }
        }
        target += L'"';
        for (size_t i = 0; i < target.size() / 2; ++i) {
            std::swap(target[i], target[target.size() - i - 1]);
        }
        return target;
    }

    static wchar_t* make_args(const std::dynarray<std::wstring>& args) {
        strbuilder res; 
        for (size_t i = 0; i < args.size() - 1; ++i) {
            res += quote_arg(args[i]);
            if (i + 2 != args.size()) {
                res += L" ";
            }
        }
        return res.string();
    }

    static wchar_t* make_env(std::map<std::wstring, std::wstring, ignore_case::less<std::wstring>>& set, std::set<std::wstring, ignore_case::less<std::wstring>>& del)
    {
        wchar_t* es = GetEnvironmentStringsW();
        if (es == 0) {
            return nullptr;
        }
        try {
            strbuilder res;
            wchar_t* escp = es;
            while (*escp != L'\0') {
                std::wstring str = escp;
                std::wstring::size_type pos = str.find(L'=');
                std::wstring key = str.substr(0, pos);
                if (del.find(key) != del.end()) {
                    continue;
                }
                std::wstring val = str.substr(pos + 1, str.length());
                auto it = set.find(key);
                if (it != set.end()) {
                    val = it->second;
                    set.erase(it);
                }
                res += key;
                res += L"=";
                res += val;
                res += L"\0";

                escp += str.length() + 1;
            }
            for (auto& e : set) {
                const std::wstring& key = e.first;
                const std::wstring& val = e.second;
                if (del.find(key) != del.end()) {
                    continue;
                }
                res += key;
                res += L"=";
                res += val;
                res += L"\0";
            }
            return res.string();
        }
        catch (...) {
        }
        FreeEnvironmentStringsW(es);
        return nullptr;
    }

    spawn::spawn()
        : inherit_handle_(false)
        , flags_(0)
    {
        memset(&si_, 0, sizeof(STARTUPINFOW));
        memset(&pi_, 0, sizeof(PROCESS_INFORMATION));
        si_.cb = sizeof(STARTUPINFOW);
        si_.dwFlags = 0;
        si_.hStdInput = INVALID_HANDLE_VALUE;
        si_.hStdOutput = INVALID_HANDLE_VALUE;
        si_.hStdError = INVALID_HANDLE_VALUE;
    }

    spawn::~spawn() {
        ::CloseHandle(pi_.hThread);
        ::CloseHandle(pi_.hProcess);
    }

    bool spawn::set_console(console type) {
		flags_ &= ~(CREATE_NO_WINDOW | CREATE_NEW_CONSOLE);
        switch (type) {
        case console::eInherit:
            break;
        case console::eDisable:
            flags_ |= CREATE_NO_WINDOW;
            break;
        case console::eNew:
            flags_ |= CREATE_NEW_CONSOLE;
            break;
		default:
			return false;
        }
        return true;
    }

    bool spawn::hide_window() {
        si_.dwFlags |= STARTF_USESHOWWINDOW;
        si_.wShowWindow = SW_HIDE;
        return true;
    }

	void spawn::suspended() {
		flags_ |= CREATE_SUSPENDED;
	}
	
    void spawn::redirect(stdio type, FILE* f) {
        si_.dwFlags |= STARTF_USESTDHANDLES;
        inherit_handle_ = true;
        HANDLE h = (HANDLE)_get_osfhandle(_fileno(f));
        ::SetHandleInformation(h, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
        switch (type) {
        case stdio::eInput:
            si_.hStdInput = h;
            break;
        case stdio::eOutput:
            si_.hStdOutput = h;
            break;
        case stdio::eError:
            si_.hStdError = h;
            break;
        }
    }

    bool spawn::exec(const std::dynarray<std::wstring>& args, const wchar_t* cwd) {
        std::unique_ptr<wchar_t[]> environment;
        if (!set_env_.empty() || !del_env_.empty()) {
            environment.reset(make_env(set_env_, del_env_));
            flags_ |= CREATE_UNICODE_ENVIRONMENT;
        }

        std::unique_ptr<wchar_t[]> command_line(make_args(args));
        if (!::CreateProcessW(
            args[0].c_str(),
            command_line.get(),
            NULL, NULL,
            inherit_handle_,
            flags_ | NORMAL_PRIORITY_CLASS,
            environment.get(),
            cwd,
            &si_, &pi_
        ))
        {
            return false;
        }
        ::CloseHandle(si_.hStdInput);
        ::CloseHandle(si_.hStdOutput);
        ::CloseHandle(si_.hStdError);
        return true;
    }

    void spawn::env_set(const std::wstring& key, const std::wstring& value) {
        set_env_[key] = value;
    }

    void spawn::env_del(const std::wstring& key) {
        del_env_.insert(key);
    }

    PROCESS_INFORMATION& spawn::pi() {
        return pi_;
    }

    process::process(spawn& spawn)
        : PROCESS_INFORMATION(spawn.pi())
    { }

    process::process(process& pi)
        : PROCESS_INFORMATION(pi)
    {
        memset(&pi, 0, sizeof(PROCESS_INFORMATION));
    }

    process::~process() {
        ::CloseHandle(hThread);
        ::CloseHandle(hProcess);
    }

    uint32_t process::wait() {
        wait(INFINITE);
        return exit_code();
    }

    bool process::wait(uint32_t timeout) {
        return ::WaitForSingleObject(hProcess, timeout) == WAIT_OBJECT_0;
    }
    
    bool process::is_running() {
        if (exit_code() == STILL_ACTIVE) {
            return !wait(0);
        }
        return false;
    }

    bool process::kill(uint32_t timeout) {
        bool result = (::TerminateProcess(hProcess, 0) != FALSE);
        if (result && timeout) {
            return wait(timeout);
        }
        return result;
    }

	bool process::resume() {
		return (DWORD)-1 != ::ResumeThread(hThread);
	}

    uint32_t process::exit_code() {
        DWORD ret = 0;
        if (!::GetExitCodeProcess(hProcess, &ret)) {
            return 0;
        }
        return (int32_t)ret;
    }

    uint32_t process::get_id() const {
        return (uint32_t)dwProcessId;
    }

    namespace pipe {
        std::pair<FILE*, FILE*> open() {
            SECURITY_ATTRIBUTES sa;
            sa.nLength = sizeof(SECURITY_ATTRIBUTES);
            sa.bInheritHandle = FALSE;
            sa.lpSecurityDescriptor = NULL;
            HANDLE read_pipe = NULL, write_pipe = NULL;
            if (!::CreatePipe(&read_pipe, &write_pipe, &sa, 0)) {
                return std::make_pair((FILE*)NULL, (FILE*)NULL);
            }
            FILE* rd = _fdopen(_open_osfhandle((intptr_t)read_pipe, _O_RDONLY | _O_BINARY), "rb");
            FILE* wr = _fdopen(_open_osfhandle((intptr_t)write_pipe, _O_WRONLY | _O_BINARY), "wb");
            return std::make_pair(rd, wr);
        }

        int peek(FILE* f) {
            DWORD rlen = 0;
            if (PeekNamedPipe((HANDLE)_get_osfhandle(_fileno(f)), 0, 0, 0, &rlen, 0)) {
                return rlen;
            }
            return 0;
        }
    }
}}}

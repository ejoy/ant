#include "subprocess.h"
#include "sharedmemory_win.h"
#include "args_helper.h"
#include <Windows.h>
#include <Shobjidl.h>
#include <memory>
#include <deque>
#include <thread>
#include <assert.h>
#include <fcntl.h>
#include <io.h>
#include <signal.h>

#define SIGKILL 9

#ifdef __MINGW32__
extern "C" {
const GUID CLSID_TaskbarList = { 0x56FDF344, 0xFD6D, 0x11D0, {0x95, 0x8A, 0x00, 0x60, 0x97, 0xC9, 0xA0, 0x90} };
const GUID IID_ITaskbarList  = { 0x56FDF342, 0xFD6D, 0x11D0, {0x95, 0x8A, 0x00, 0x60, 0x97, 0xC9, 0xA0, 0x90} };
const GUID IID_ITaskbarList2 = { 0x602D4995, 0xB13A, 0x429b, {0xA6, 0x6E, 0x19, 0x35, 0xE4, 0x4F, 0x43, 0x17} };
const GUID IID_ITaskbarList3 = { 0xEA1AFB91, 0x9E28, 0x4B86, {0x90, 0xE9, 0x9E, 0x9F, 0x8A, 0x5E, 0xEF, 0xAF} }; 
}
#endif

namespace ant::win::subprocess {

    static wchar_t* make_array_args(const std::vector<std::wstring>& args, std::wstring_view prefix = std::wstring_view()) {
        strbuilder<wchar_t> res;
        if (!prefix.empty()) {
            res += prefix;
        }
        for (size_t i = 0; i < args.size(); ++i) {
            res += quote_arg(args[i]);
            if (i + 1 != args.size()) {
                res += L" ";
            }
        }
        return res.string();
    }

    static wchar_t* make_string_args(const std::wstring& app, const std::wstring& cmd, std::wstring_view prefix = std::wstring_view()) {
        strbuilder<wchar_t> res;
        if (!prefix.empty()) {
            res += prefix;
        }
        res += quote_arg(app);
        res += L" ";
        res += cmd;
        return res.string();
    }

    static wchar_t* make_args(const args_t& args, std::wstring_view prefix = std::wstring_view()) {
        switch (args.type) {
        case args_t::type::array:
            return make_array_args(args, prefix);
        case args_t::type::string:
            return make_string_args(args[0], args[1], prefix);
        default:
            return 0;
        }
    }

    static wchar_t* make_env(std::map<std::wstring, std::wstring, ignore_case::less<std::wstring>>& set, std::set<std::wstring, ignore_case::less<std::wstring>>& del)
    {
        wchar_t* es = GetEnvironmentStringsW();
        if (es == 0) {
            return nullptr;
        }
        try {
            strbuilder<wchar_t> res;
            wchar_t* escp = es;
            while (*escp != L'\0') {
                std::wstring str = escp;
                std::wstring::size_type pos = str.find(L'=');
                std::wstring key = str.substr(0, pos);
                if (del.find(key) != del.end()) {
                    escp += str.length() + 1;
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

    static HANDLE create_job() {
        SECURITY_ATTRIBUTES attr;
        memset(&attr, 0, sizeof attr);
        attr.bInheritHandle = FALSE;

        JOBOBJECT_EXTENDED_LIMIT_INFORMATION info;
        memset(&info, 0, sizeof info);
        info.BasicLimitInformation.LimitFlags =
            JOB_OBJECT_LIMIT_BREAKAWAY_OK
            | JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK
            | JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            | JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION
            ;

        HANDLE job = CreateJobObjectW(&attr, NULL);
        if (job == NULL) {
            return NULL;
        }
        if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &info, sizeof info)) {
            return NULL;
        }
        return job;
    }

    static bool join_job(HANDLE process) {
        static HANDLE job = create_job();
        if (job) {
            return false;
        }
        if (!AssignProcessToJobObject(job, process)) {
            DWORD err = GetLastError();
            if (err != ERROR_ACCESS_DENIED) {
                return false;
            }
        }
        return true;
    }

    static HWND console_window(DWORD pid) {
        DWORD wpid;
        HWND wnd = NULL;
        do {
            wnd = FindWindowExW(NULL, wnd, L"ConsoleWindowClass", NULL);
            if (wnd == NULL) {
                break;
            }
            GetWindowThreadProcessId(wnd, &wpid);
        } while (pid != wpid);
        return wnd;
    }

    bool hide_taskbar(HWND w) {
        ITaskbarList* taskbar;
        ::CoInitializeEx(NULL, COINIT_MULTITHREADED);
        if (SUCCEEDED(CoCreateInstance(CLSID_TaskbarList, NULL, CLSCTX_INPROC_SERVER, IID_ITaskbarList, (void**)&taskbar))) {
            taskbar->HrInit();
            taskbar->DeleteTab(w);
            taskbar->Release();
            return true;
        }
        return false;
    }

    static bool hide_console(PROCESS_INFORMATION& pi) {
        HANDLE hProcess = NULL;
        if (!::DuplicateHandle(
            ::GetCurrentProcess(),
            pi.hProcess,
            ::GetCurrentProcess(),
            &hProcess,
            0, FALSE, DUPLICATE_SAME_ACCESS)
            ) {
            return false;
        }

        std::thread thd([=]() {
            PROCESS_INFORMATION cpi;
            cpi.dwProcessId = pi.dwProcessId;
            cpi.dwThreadId = pi.dwThreadId;
            cpi.hThread = NULL;
            cpi.hProcess = hProcess;
            process process(std::move(cpi));
            for (;; std::this_thread::sleep_for(std::chrono::milliseconds(10))) {
                if (!process.is_running()) {
                    return;
                }
                HWND wnd = console_window(process.get_id());
                if (wnd) {
                    SetWindowPos(wnd, NULL, -10000, -10000, 0, 0, SWP_HIDEWINDOW);
                    hide_taskbar(wnd);
                    return;
                }
            }
        });
        thd.detach();
        return true;
    }

    spawn::spawn()
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

    void spawn::search_path() {
        search_path_ = true;
    }

    bool spawn::set_console(console type) {
		console_ = type;
        flags_ &= ~(CREATE_NO_WINDOW | CREATE_NEW_CONSOLE | DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP);
        switch (type) {
        case console::eInherit:
            break;
        case console::eDetached:
            flags_ |= DETACHED_PROCESS & CREATE_NEW_PROCESS_GROUP;
            break;
        case console::eDisable:
            flags_ |= CREATE_NO_WINDOW;
            break;
        case console::eNew:
        case console::eHide:
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

    void spawn::detached() {
        set_console(console::eDetached);
        detached_ = true;
    }

    void spawn::redirect(stdio type, file::handle h) {
        si_.dwFlags |= STARTF_USESTDHANDLES;
        inherit_handle_ = true;
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
        default:
            break;
        }
    }

    bool spawn::raw_exec(const wchar_t* application, wchar_t* commandline, const wchar_t* cwd) {
        std::unique_ptr<wchar_t[]> command_line(commandline);
        std::unique_ptr<wchar_t[]> environment;
        if (!set_env_.empty() || !del_env_.empty()) {
            environment.reset(make_env(set_env_, del_env_));
            flags_ |= CREATE_UNICODE_ENVIRONMENT;
        }
        bool resume = false;
        if (!::CreateProcessW(
            application,
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
        if (!detached_) {
            join_job(pi_.hProcess);
        }
        if (console_ == console::eHide) {
            hide_console(pi_);
        }
        if (resume) {
            ::ResumeThread(pi_.hThread);
        }
        return true;
    }

    bool spawn::exec(const args_t& args, const wchar_t* cwd) {
        if (args.size() == 0) {
            return false;
        }
        wchar_t* command = make_args(args);
        if (!command) {
            return false;
        }
        return raw_exec(search_path_ ? 0 : args[0].c_str(), command, cwd);
    }

    void spawn::env_set(const std::wstring& key, const std::wstring& value) {
        set_env_[key] = value;
    }

    void spawn::env_del(const std::wstring& key) {
        del_env_.insert(key);
    }

    process::process(spawn& spawn)
        : pi_(spawn.pi_)
    {
        memset(&spawn.pi_, 0, sizeof(PROCESS_INFORMATION));
    }

    process::~process() {
        ::CloseHandle(pi_.hThread);
        ::CloseHandle(pi_.hProcess);
    }

    uint32_t process::wait() {
        wait(INFINITE);
        return exit_code();
    }

    bool process::wait(uint32_t timeout) {
        return ::WaitForSingleObject(pi_.hProcess, timeout) == WAIT_OBJECT_0;
    }

    bool process::is_running() {
        if (exit_code() == STILL_ACTIVE) {
            return !wait(0);
        }
        return false;
    }

    bool process::kill(int signum) {
        switch (signum) {
        case SIGTERM:
        case SIGKILL:
        case SIGINT:
            if (TerminateProcess(pi_.hProcess, (signum << 8))) {
                return wait(5000);
            }
            return false;
        case 0:
            return is_running();
        default:
            return false;
        }
    }

    bool process::resume() {
        return (DWORD)-1 != ::ResumeThread(pi_.hThread);
    }

    uint32_t process::exit_code() {
        DWORD ret = 0;
        if (!::GetExitCodeProcess(pi_.hProcess, &ret)) {
            return 0;
        }
        return (int32_t)ret;
    }

    uint32_t process::get_id() const {
        return (uint32_t)pi_.dwProcessId;
    }

    uintptr_t process::native_handle() {
        return (uintptr_t)pi_.hProcess;
    }

    namespace pipe {
        FILE* open_result::open_read() {
            return file::open_read(rd);
        }

        FILE* open_result::open_write() {
            return file::open_write(wr);
        }

        open_result open() {
            SECURITY_ATTRIBUTES sa;
            sa.nLength = sizeof(SECURITY_ATTRIBUTES);
            sa.bInheritHandle = FALSE;
            sa.lpSecurityDescriptor = NULL;
            HANDLE read_pipe = NULL, write_pipe = NULL;
            if (!::CreatePipe(&read_pipe, &write_pipe, &sa, 0)) {
                return { file::handle::invalid(), file::handle::invalid() };
            }
            return { file::handle(read_pipe), file::handle(write_pipe) };
        }

        int peek(FILE* f) {
            DWORD rlen = 0;
            if (PeekNamedPipe(file::get_handle(f), 0, 0, 0, &rlen, 0)) {
                return rlen;
            }
            return -1;
        }
    }
}

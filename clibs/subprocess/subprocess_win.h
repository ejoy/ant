#pragma once

#include <Windows.h>
#include <map>
#include <set>
#include <vector>

namespace ant::win::subprocess {
    namespace ignore_case {
        template <class T> struct less;
        template <> struct less<wchar_t> {
            bool operator()(const wchar_t& lft, const wchar_t& rht) const
            {
                return (towlower(static_cast<wint_t>(lft)) < towlower(static_cast<wint_t>(rht)));
            }
        };
        template <> struct less<std::wstring> {
            bool operator()(const std::wstring& lft, const std::wstring& rht) const
            {
                return std::lexicographical_compare(lft.begin(), lft.end(), rht.begin(), rht.end(), less<wchar_t>());
            }
        };
    }

    enum class console {
        eInherit,
        eDisable,
        eNew,
    };
    enum class stdio {
        eInput,
        eOutput,
        eError,
    };

    class spawn;
    class process : public PROCESS_INFORMATION {
    public:
        process(spawn& spawn);
        process(process&& pi);
        process(PROCESS_INFORMATION&& pi);
        ~process();
        process& operator=(process&& pi);
        bool      is_running();
        bool      kill(int signum);
        uint32_t  wait();
        uint32_t  get_id() const;
        bool      resume();
        uintptr_t native_handle();

    private:
        bool     wait(uint32_t timeout);
        uint32_t exit_code();
    };

    class spawn {
    public:
        spawn();
        ~spawn();
        bool set_console(console type);
        bool hide_window();
        void suspended();
        void redirect(stdio type, FILE* f);
        void env_set(const std::wstring& key, const std::wstring& value);
        void env_del(const std::wstring& key);
        bool exec(const std::vector<std::wstring>& args, const wchar_t* cwd);
        bool exec(const std::wstring& app, const std::wstring& cmd, const wchar_t* cwd);
        PROCESS_INFORMATION release();

    private:
        std::map<std::wstring, std::wstring, ignore_case::less<std::wstring>> set_env_;
        std::set<std::wstring, ignore_case::less<std::wstring>>               del_env_;
        STARTUPINFOW            si_;
        PROCESS_INFORMATION     pi_;
        bool                    inherit_handle_;
        DWORD                   flags_;
    };

    namespace pipe {
		struct open_result {
			FILE* rd;
			FILE* wr;
		};
        open_result open();
        int         peek(FILE* f);
    }
}

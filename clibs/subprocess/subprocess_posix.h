#pragma once

#include <stdint.h>
#include <string>
#include <stdio.h>
#include <map>
#include <set>
#include <vector>

namespace base { namespace posix { namespace subprocess {
    enum class stdio {
        eInput,
        eOutput,
        eError,
    };

    class spawn;
    class process {
    public:
        process(spawn& spawn);
        bool      is_running();
        bool      kill(int signum);
        uint32_t  wait();
        uint32_t  get_id() const;
        bool      resume();
        uintptr_t native_handle();

        int pid;
    };

    class spawn {
        friend class process;
    public:
        spawn();
        ~spawn();
        void suspended();
        void redirect(stdio type, FILE* f);
        void env_set(const std::string& key, const std::string& value);
        void env_del(const std::string& key);
        bool exec(std::vector<char*>& args, const char* cwd);

    private:
        std::map<std::string, std::string> set_env_;
        std::set<std::string>              del_env_;
        int                                fds_[3];
        int                                pid_;
        bool                               suspended_;
    };

    namespace pipe {
        std::pair<FILE*, FILE*> open();
        int                     peek(FILE* f);
    }
}}}

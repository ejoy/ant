#pragma once

#include <stdint.h>
#include <string>
#include <stdio.h>
#include <map>
#include <set>
#include "../dynarray.h"

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
        bool     is_running() { return false; }
        bool     kill(uint32_t timeout) { return false; }
        uint32_t exit_code() { return -1; }
        uint32_t wait() { return -1; }
        bool     wait(uint32_t timeout) { return false; }
        uint32_t get_id() const { return -1; }
    };

    class spawn {
    public:
        spawn();
        ~spawn();
        void redirect(stdio type, FILE* f);
        void env_set(const std::string& key, const std::string& value);
        void env_del(const std::string& key);
        bool exec(const char* app, const std::dynarray<char*>& args, const char* cwd);

    private:
        std::map<std::string, std::string> set_env_;
        std::set<std::string>              del_env_;
		int                                fds_[3];
    };

    namespace pipe {
        std::pair<FILE*, FILE*> open();
        int                     peek(FILE* f);
	}
}}
namespace subprocess = posix::subprocess;
}

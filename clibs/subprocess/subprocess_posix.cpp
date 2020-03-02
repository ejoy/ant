#include "subprocess.h"
#include <deque>
#include <memory.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <assert.h>

#if defined(__APPLE__)
# include <crt_externs.h>
# define environ (*_NSGetEnviron())
#else
extern char **environ;
#endif

namespace ant::posix::subprocess {

    args_t::~args_t() {
        for (size_t i = 0; i < size(); ++i) {
            delete[]((*this)[i]);
        }
    }

    void args_t::push(char* str) {
        push_back(str);
    }

    void args_t::push(const std::string& str) {
        std::unique_ptr<char[]> tmp(new char[str.size() + 1]);
        memcpy(tmp.get(), str.data(), str.size() + 1);
        push(tmp.release());
    }

    static void sigalrm_handler (int) {
        // Nothing to do
    }
    static bool wait_with_timeout(pid_t pid, int *status, int timeout) {
        assert(pid > 0);
        assert(timeout >= -1);
        if (timeout <= 0) {
            if (timeout == -1) {
                ::waitpid(pid, status, 0);
            }
            return 0 != ::waitpid(pid, status, WNOHANG);
        }
        pid_t err;
        struct sigaction sa, old_sa;
        sa.sa_handler = sigalrm_handler;
        sigemptyset(&sa.sa_mask);
        sa.sa_flags = 0;
        ::sigaction(SIGALRM, &sa, &old_sa);
        ::alarm(timeout);
        err = ::waitpid(pid, status, 0);
        ::alarm(0);
        ::sigaction(SIGALRM, &old_sa, NULL);
        return err == pid;
    }

    template <class T>
    struct allocarray {
        size_t size;
        size_t maxsize;
        T* data;
        allocarray()
            : size(0)
            , maxsize(16)
            , data((T*)malloc(maxsize * sizeof(T))) {
            if (!data) {
                throw std::bad_alloc();
            }
        }
        ~allocarray() {
            delete[] data;
        }
        T* release() {
            append(0);
            T* r = data;
            data = nullptr;
            return r;
        }
        void append(T t) {
            if (size + 1 > maxsize) {
                maxsize *= 2;
                data = (T*)realloc(data, maxsize * sizeof(T));
                if (!data) {
                    throw std::bad_alloc();
                }
            }
            data[size++] = t;
        }
    };

    static char*  env_aloc(const std::string& key, const std::string& val) {
        size_t n = key.size() + val.size() + 2;
        char* res = (char*)malloc(n);
        if (!res) {
            return 0;
        }
        memcpy(res, key.data(), key.size());
        res[key.size()] = '=';
        memcpy(res+key.size()+1, val.data(), val.size());
        res[n-1] = '\0';
        return res;
    }

    static char** make_env(std::map<std::string, std::string>& set, std::set<std::string>& del) {
        char** es = environ;
        if (es == 0) {
            return nullptr;
        }
        try {
            allocarray<char*> envs;
            for (; *es; ++es) {
                std::string str = *es;
                std::string::size_type pos = str.find(L'=');
                std::string key = str.substr(0, pos);
                if (del.find(key) != del.end()) {
                    continue;
                }
                std::string val = str.substr(pos + 1, str.length());
                auto it = set.find(key);
                if (it != set.end()) {
                    val = it->second;
                    set.erase(it);
                }
                envs.append(env_aloc(key, val));
            }
            for (auto& e : set) {
                const std::string& key = e.first;
                const std::string& val = e.second;
                if (del.find(key) != del.end()) {
                    continue;
                }
                envs.append(env_aloc(key, val));
            }
            return envs.release();
        }
        catch (...) {
        }
        return nullptr;
    }

    spawn::spawn()
    {
        fds_[0] = -1;
        fds_[1] = -1;
        fds_[2] = -1;
    }

    spawn::~spawn()
    { }

    void spawn::suspended() {
        suspended_ = true;
    }

    void spawn::detached() {
        detached_ = true;
    }

    void spawn::redirect(stdio type, file::handle h) { 
        switch (type) {
        case stdio::eInput:
            fds_[0] = h;
            break;
        case stdio::eOutput:
            fds_[1] = h;
            break;
        case stdio::eError:
            fds_[2] = h;
            break;
        default:
            break;
        }
    }

    void spawn::env_set(const std::string& key, const std::string& value) {
        set_env_[key] = value;
    }

    void spawn::env_del(const std::string& key) {
        del_env_.insert(key);
    }

    bool spawn::raw_exec(char* const args[], const char* cwd) {
        pid_t pid = fork();
        if (pid == -1) {
            return false;
        }
        if (pid == 0) {
            if (detached_) {
                setsid();
            }
            if (!set_env_.empty() || !del_env_.empty()) {
                environ = make_env(set_env_, del_env_);
            }
            if (cwd && chdir(cwd)) {
                _exit(127);
            }
            if (suspended_) {
                ::kill(getpid(), SIGSTOP);
            }
            execvp(args[0], args);
            _exit(127);
        }
        pid_ = pid;
        return true;

    }

    static void split_accept(args_t& args, const char* str, size_t len) {
        char* data = new char[len + 1];
        size_t j = 0;
        for (size_t i = 0; i < len; ++i, ++j) {
            if (str[i] == '\\' && i + 1 < len) {
                i++;
            }
            data[j] = str[i];
        }
        data[j] = 0;
        args.push(data);
    }
    static void split_str(args_t& args, const char*& z) {
        const char* start = z;
        for (;;) {
            switch (*z) {
            case '\0':
                split_accept(args, start, z - start);
                return;
            case '"':
                split_accept(args, start, z - start);
                z++;
                return;
            case '\\':
                z++;
                if (*z != '\0') {
                    z++;
                }
                break;
            default:
                z++;
                break;
            }
        }
    }
    static void split_arg(args_t& args, const char*& z) {
        const char* start = z;
        for (;;) {
            switch (*z) {
            case '\0':
            case ' ':
            case '\t':
                split_accept(args, start, z - start);
                return;
            case '"':
                z++;
                split_str(args, z);
                return;
            case '\\':
                z++;
                switch (*z) {
                case '\0':
                case ' ':
                case '\t':
                    break;
                default:
                    z++;
                    break;
                }
                break;
            default:
                z++;
                break;
            }
        }
    }
    static void split_next(args_t& args, const char* z) {
        for (;;) {
            switch (*z) {
            case '\0':
                return;
            case ' ':
            case '\t':
                z++;
                break;
            default:
                split_arg(args, z);
                break;
            }
        }
    }
    static void split(args_t& args) {
        if (args.size() < 2) {
            return;
        }
        else if (args.size() > 2) {
            args.resize(2);
        }
        args.push(std::string(args[0]));
        split_next(args, args[1]);
    }
    bool spawn::exec(args_t& args, const char* cwd) {
        if (args.size() == 0) {
            return false;
        }
        switch (args.type) {
        case args_t::type::array:
            args.push(nullptr);
            return raw_exec(args.data(), cwd);
        case args_t::type::string:
            split(args);
            args.push(nullptr);
            return raw_exec(args.data() + 2, cwd);
        default:
            return false;
        }
    }

    process::process(spawn& spawn)
    : pid(spawn.pid_)
    { }

    bool     process::is_running() {
        return (0 == ::waitpid(pid, 0, WNOHANG));
    }

    bool     process::kill(int signum) {
        if (0 == ::kill(pid, signum)) {
            if (signum == 0) {
                return true;
            }
            return wait_with_timeout(pid, &status, 5);
        }
        return false;
    }

    uint32_t process::wait() {
        if (!wait_with_timeout(pid, &status, -1)) {
            return 0;
        }
        int exit_status = WIFEXITED(status)? WEXITSTATUS(status) : 0;
        int term_signal = WIFSIGNALED(status)? WTERMSIG(status) : 0;
        return (term_signal << 8) | exit_status;
    }

    bool process::resume() {
        return kill(SIGCONT);
    }

    uint32_t process::get_id() const {
        return pid;
    }

    uintptr_t process::native_handle() {
        return pid;
    }

    namespace pipe {
        FILE* open_result::open_read() {
            return file::open_read(rd);
        }
        FILE* open_result::open_write() {
            return file::open_write(wr);
        }
        open_result open() {
            int fds[2];
            if (!net::socket::blockpair(fds)) {
                return { file::handle::invalid(), file::handle::invalid() };
            }
            return { file::handle(fds[0]), file::handle(fds[1]) };
        }
        int peek(FILE* f) {
            char tmp[256];
            int rc = recv(file::get_handle(f), tmp, sizeof(tmp), MSG_PEEK | MSG_DONTWAIT);
            if (rc == 0) {
                return -1;
            }
            else if (rc < 0) {
                if (errno == EAGAIN || errno == EINTR) {
                    return 0;
                }
                return -1;
            }
            return rc;
        }
    }
}

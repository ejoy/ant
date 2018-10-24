#include "subprocess.h"
#include <deque>
#include <memory.h>

#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

namespace base { namespace posix { namespace subprocess {

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
            T* r = data;
            data = nullptr;
            return r;
        }
        void append(T const& t) {
            if (size + 1 > maxsize) {
                maxsize *= 2;
                data = (T*)realloc(data, maxsize);
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

    spawn::spawn() {
        fds_[0] = -1;
        fds_[1] = -1;
        fds_[2] = -1;
    }

    spawn::~spawn()
    { }

    void spawn::redirect(stdio type, FILE* f) { 
        switch (type) {
        case stdio::eInput:
            fds_[0] = fileno(f);
            break;
        case stdio::eOutput:
            fds_[1] = fileno(f);
            break;
        case stdio::eError:
            fds_[2] = fileno(f);
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

    bool spawn::exec(const std::vector<char*>& args, const char* cwd) {
        pid_t pid = fork();
        if (pid == -1) {
            return false;
        }
        if (pid == 0) {
            for (int i = 0; i < 3; ++i) {
                if (fds_[i] > 0) {
                    if (dup2(fds_[i], i) == -1) {
                        _exit(127);
                    }
                }
            }
            if (!set_env_.empty() || !del_env_.empty()) {
                environ = make_env(set_env_, del_env_);
            }
            if (cwd && chdir(cwd)) {
                _exit(127);
            }
            execvp(args[0], args.data());
            _exit(127);
        }
        pid_ = pid;
        for (int i = 0; i < 3; ++i) {
            if (fds_[i] > 0) {
                close(fds_[i]);
            }
        }
        return true;
    }

    process::process(spawn& spawn)
    : pid(spawn.pid_)
    { }

    bool     process::is_running() {
        return (0 == ::waitpid(pid, 0, WNOHANG));
    }

    bool     process::kill(int signum) {
        return ::kill(pid, signum);
    }

    uint32_t process::wait() {
        int status = 0;
        if (-1 == ::waitpid(pid, &status, 0)) {
            return 0;
        }
        return WIFEXITED(status)? WEXITSTATUS(status): 0;
    }

    uint32_t process::get_id() const {
        return pid;
    }

    namespace pipe {
        static bool cloexec(int fd, bool set) {
            int r;
            do
                r = ioctl(fd, set ? FIOCLEX : FIONCLEX);
            while (r == -1 && errno == EINTR);
            return !r;
        }
        static bool create(int fds[2]) {
            if (socketpair(AF_UNIX, SOCK_STREAM, 0, fds)) {
                return false;
            }
            cloexec(fds[0], true);
            cloexec(fds[1], true);
            return true;
        }
        std::pair<FILE*, FILE*> open() {
            int fds[2];
            if (!create(fds)) {
                return std::make_pair((FILE*)NULL, (FILE*)NULL);
            }
            FILE* rd = fdopen(fds[0], "rb");
            FILE* wr = fdopen(fds[1], "wb");
            return std::make_pair(rd, wr);
        }
        int peek(FILE* f) {
            int count;
            return (ioctl(fileno(f), FIONREAD, (char *) &count) < 0 ? -1 : count);
        }
    }
}}}

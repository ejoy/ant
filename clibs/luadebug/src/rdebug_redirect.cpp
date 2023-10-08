#include "rdebug_redirect.h"

#if defined(_WIN32)

#    include <fcntl.h>
#    include <io.h>
#    include <stdio.h>
#    include <windows.h>

namespace luadebug::stdio {

    static DWORD handles[] = {
        STD_INPUT_HANDLE,
        STD_OUTPUT_HANDLE,
        STD_ERROR_HANDLE,
    };

    static FILE* files[] = {
        stdin,
        stdout,
        stderr,
    };

    static void set_handle(std_fd type, HANDLE handle) {
        SetStdHandle(handles[(int)type], handle);
        int fd = _open_osfhandle((intptr_t)handle, type == std_fd::STDIN ? _O_RDONLY : _O_WRONLY);
        if (fd < 0) {
            return;
        }
        FILE* fp = _fdopen(fd, type == std_fd::STDIN ? "r" : "w");
        if (fp) {
            _dup2(_fileno(fp), _fileno(files[(int)type]));
        }
    }

    std_redirect::handle_t kInvalidHandle = INVALID_HANDLE_VALUE;

    std_redirect::std_redirect()
        : m_pipe { kInvalidHandle, kInvalidHandle }
        , m_old(kInvalidHandle)
        , m_type(std_fd::STDOUT) {}

    std_redirect::~std_redirect() {
        close();
    }

    bool std_redirect::open(std_fd type) {
        SECURITY_ATTRIBUTES attr = { sizeof(SECURITY_ATTRIBUTES), 0, true };
        if (!::CreatePipe(&m_pipe[0], &m_pipe[1], &attr, 0)) {
            return false;
        }
        m_type = type;
        m_old  = GetStdHandle(handles[(int)type]);
        if (type == std_fd::STDIN) {
            set_handle(type, m_pipe[0]);
            m_pipe[0] = kInvalidHandle;
        }
        else {
            set_handle(type, m_pipe[1]);
            m_pipe[1] = kInvalidHandle;
        }
        return true;
    }

    void std_redirect::close() {
        if (m_old != kInvalidHandle) {
            SetStdHandle(handles[(int)m_type], m_old);
            m_old = kInvalidHandle;
        }

        if (m_pipe[0] != kInvalidHandle) {
            ::CloseHandle(m_pipe[0]);
            m_pipe[0] = kInvalidHandle;
        }

        if (m_pipe[1] != kInvalidHandle) {
            ::CloseHandle(m_pipe[1]);
            m_pipe[1] = kInvalidHandle;
        }
    }

    size_t std_redirect::peek() {
        DWORD rlen = 0;
        if (!PeekNamedPipe(m_pipe[0], 0, 0, 0, &rlen, 0)) {
            return 0;
        }
        return rlen;
    }

    size_t std_redirect::read(char* buf, size_t len) {
        if (!peek()) {
            return 0;
        }
        DWORD rlen = 0;
        if (!ReadFile(m_pipe[0], buf, static_cast<DWORD>(len), &rlen, 0)) {
            return 0;
        }
        return rlen;
    }
}

#else

#    include <fcntl.h>
#    include <unistd.h>
#    if defined(__APPLE__)
#        include <assert.h>
#    endif

namespace luadebug::stdio {
    std_redirect::handle_t kInvalidHandle = -1;

    std_redirect::std_redirect()
        : m_pipe { kInvalidHandle, kInvalidHandle }
        , m_old(kInvalidHandle)
        , m_type(std_fd::STDOUT) {}

    std_redirect::~std_redirect() {
        close();
    }

#    if defined(__APPLE__)
    static void no_blocking(int s) {
        int flags = fcntl(s, F_GETFL, 0);
        int rc    = fcntl(s, F_SETFL, flags | O_NONBLOCK);
        (void)rc;
        assert(rc == 0);
    }
    static int pipe2(int pipefd[2], int flags) {
        assert(flags == O_NONBLOCK);
        int ok = pipe(pipefd);
        if (ok == -1) {
            return ok;
        }
        no_blocking(pipefd[0]);
        no_blocking(pipefd[1]);
        return ok;
    }
#    endif

    bool std_redirect::open(std_fd type) {
        if (pipe2(m_pipe, O_NONBLOCK) == -1) {
            return false;
        }
        m_old  = ::dup((int)type);
        m_type = type;
        if (m_type == std_fd::STDIN) {
            ::dup2(m_pipe[0], (int)m_type);
            ::close(m_pipe[0]);
            m_pipe[0] = kInvalidHandle;
        }
        else {
            ::dup2(m_pipe[1], (int)m_type);
            ::close(m_pipe[1]);
            m_pipe[1] = kInvalidHandle;
        }
        return true;
    }

    void std_redirect::close() {
        if (m_old != kInvalidHandle) {
            ::dup2(m_old, (int)m_type);
            ::close(m_old);
            m_old = kInvalidHandle;
        }
        if (m_pipe[0] != kInvalidHandle) {
            ::close(m_pipe[0]);
            m_pipe[0] = kInvalidHandle;
        }
        if (m_pipe[1] != kInvalidHandle) {
            ::close(m_pipe[1]);
            m_pipe[1] = kInvalidHandle;
        }
    }

    size_t std_redirect::read(char* buf, size_t len) {
        ssize_t r = ::read(m_pipe[0], (void*)buf, len);
        return r <= 0 ? 0 : r;
    }
}

#endif

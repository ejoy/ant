#pragma once

#include <stddef.h>

namespace luadebug::stdio {
    enum class std_fd {
        STDIN = 0,
        STDOUT,
        STDERR,
    };

    class std_redirect {
    public:
#if defined(_WIN32)
        typedef void* handle_t;
#else
        typedef int handle_t;
#endif
    public:
        std_redirect();
        ~std_redirect();
        bool open(std_fd type);
        void close();
        size_t read(char* buf, size_t len);
#if defined(_WIN32)
        size_t peek();
#endif
    private:
        handle_t m_pipe[2];
        handle_t m_old;
        std_fd m_type;
    };
}

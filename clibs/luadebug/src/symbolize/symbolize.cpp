#include <symbolize/symbolize.h>

#if defined(_WIN32)
#    include <symbolize/symbolize_win32.inl>
#elif defined(__APPLE__)
#    include <symbolize/symbolize_macos.inl>
#elif defined(__linux__)
#    include <symbolize/symbolize_linux.inl>
#else

namespace luadebug {
    symbol_info symbolize(const void* ptr) {
        return {};
    }
}

#endif

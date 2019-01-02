#include "error.h"
#if defined(_WIN32)
#include <Windows.h>
#include "windows_category.h"
#else
#include <errno.h>
#endif

namespace ant {
    int last_crterror() {
        return errno;
    }

    int last_syserror() {
#if defined(_WIN32)
        return ::GetLastError();
#else
        return errno;
#endif
    }

    static std::error_code make_error_code(int err) {
#if defined(_WIN32)
        return std::error_code(err, windows_category());
#else
        return std::error_code(err, std::generic_category());
#endif
    }

    std::system_error make_error(int err, const char* message) {
        return std::system_error(make_error_code(err), message ? message : "");
    }

    std::system_error make_crterror(const char* message) {
        return std::system_error(
            std::error_code(last_crterror(), std::generic_category()), 
            message ? message : ""
        );
    }

    std::system_error make_syserror(const char* message) {
        return make_error(last_syserror(), message);
    }
}

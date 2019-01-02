#pragma once

#include <system_error>

namespace ant {
    int last_syserror();
    std::system_error make_syserror(const char* message = nullptr);
    std::system_error make_error(int err, const char* message = nullptr);
}

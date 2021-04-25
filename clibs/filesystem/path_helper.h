#pragma once

#include "filesystem.h"

namespace ant::path_helper {
    fs::path dll_path(void* module_handle);
    fs::path exe_path();
    fs::path dll_path();
    bool equal(fs::path const& lhs, fs::path const& rhs);
}

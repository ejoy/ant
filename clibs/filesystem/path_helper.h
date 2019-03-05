#pragma once

#include "filesystem.h"
#include "expected.h"

namespace ant::path_helper {
    auto dll_path(void* module_handle)->nonstd::expected<fs::path, std::exception>;
    auto exe_path()->nonstd::expected<fs::path, std::exception>;
    auto dll_path()->nonstd::expected<fs::path, std::exception>;
    bool equal(fs::path const& lhs, fs::path const& rhs);
}

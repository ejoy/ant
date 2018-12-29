#pragma once

#include <system_error>

namespace ant {
    const std::error_category& windows_category() noexcept;
}

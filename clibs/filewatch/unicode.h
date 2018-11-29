#pragma once

#include <string>
#include <string_view>

namespace ant {
    std::wstring u2w(const std::string_view& str);
    std::string  w2u(const std::wstring_view& wstr);
    std::wstring a2w(const std::string_view& str);
    std::string  w2a(const std::wstring_view& wstr);
    std::string  a2u(const std::string_view& str);
    std::string  u2a(const std::string_view& str);
}

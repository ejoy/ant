#pragma once

#include <bee/config.h>
#include <string>
#include <string_view>

namespace bee {
    _BEE_API std::wstring u2w(const std::string_view& str);
    _BEE_API std::string  w2u(const std::wstring_view& wstr);
    _BEE_API std::wstring a2w(const std::string_view& str);
    _BEE_API std::string  w2a(const std::wstring_view& wstr);
    _BEE_API std::string  a2u(const std::string_view& str);
    _BEE_API std::string  u2a(const std::string_view& str);
}

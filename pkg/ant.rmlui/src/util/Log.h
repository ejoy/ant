#pragma once

#if !defined(__GLIBCXX__)
#include <bee/nonstd/format.h>
#include <bee/nonstd/print.h>

namespace Rml::Log {
template <typename... T>
void Warning(std::format_string<T...> fmt, T&&... args) {
    std::println(stderr, fmt, std::forward<T>(args)...);
}
template <typename... T>
void Error(std::format_string<T...> fmt, T&&... args) {
    std::println(stderr, fmt, std::forward<T>(args)...);
}

#else

#include <3rd/fmt/fmt/format.h>
#include <3rd/fmt/fmt/xchar.h>

namespace Rml::Log {
template <typename... T>
void Warning(fmt::format_string<T...> fmt, T&&... args) {
    fmt::println(stderr, fmt, std::forward<T>(args)...);
}
template <typename... T>
void Error(fmt::format_string<T...> fmt, T&&... args) {
    fmt::println(stderr, fmt, std::forward<T>(args)...);
}

#endif

}

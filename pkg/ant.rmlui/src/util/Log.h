#pragma once

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
}

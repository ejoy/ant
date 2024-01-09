#pragma once

#include <array>
#include <cstddef>

namespace Rml {
    template <size_t N>
    struct StaticString : std::array<char, N + 1> {
        constexpr StaticString() = default;
        constexpr StaticString(const char (&str)[N + 1]) {
            for (size_t i = 0; i < N; i++) { this->data()[i] = str[i]; }
            this->data()[N] = '\0';
        }
        constexpr size_t length() const { return N; }
    };
    template <size_t N>
    StaticString(const char (&str)[N]) -> StaticString<N - 1>;
}

#pragma once

#include <string_view>

namespace Rml {
    constexpr bool EnumIsValid(std::string_view name) noexcept {
        for (std::size_t i = name.size(); i > 0; --i) {
            const char c = name[i - 1];
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c == '_'))) {
                name.remove_prefix(i);
                break;
            }
        }
        if (name.size() > 0) {
            const char c = name[0];
            if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c == '_')) {
                return true;
            }
        }
        return false;
    }

    template <typename E, E V>
    constexpr auto EnumIsValid() noexcept {
#if __GNUC__ || __clang__
        return EnumIsValid({__PRETTY_FUNCTION__, sizeof(__PRETTY_FUNCTION__) - 2});
#elif _MSC_VER
        return EnumIsValid({__FUNCSIG__, sizeof(__FUNCSIG__) - 17});
#else
        static_assert(false, "Unsupported compiler");
#endif
    }

    template <typename E, std::size_t I = 0>
    constexpr auto EnumCount() noexcept {
        if constexpr (!EnumIsValid<E, static_cast<E>(static_cast<std::underlying_type_t<E>>(I))>()) {
            return I;
        } else {
            return EnumCount<E, I+1>();
        }
    }

    template <typename E>
    static constexpr auto EnumCountV = EnumCount<E>();

    template <auto Value>
    constexpr auto EnumName() {
#if __GNUC__ || __clang__
        std::string_view name = __PRETTY_FUNCTION__;
        std::size_t start = name.find('=') + 2;
        std::size_t end = name.size() - 1;
        name = std::string_view{name.data() + start, end - start};
        start = name.rfind("::");
        return start == std::string_view::npos ? name : std::string_view{name.data() + start + 2, name.size() - start - 2};
#elif _MSC_VER
        std::string_view name = __FUNCSIG__;
        std::size_t start = name.find('<') + 1;
        std::size_t end = name.rfind(">(");
        name = std::string_view{name.data() + start, end - start};
        start = name.rfind("::");
        return start == std::string_view::npos ? name : std::string_view{name.data() + start + 2, name.size() - start - 2};
#else
        static_assert(false, "Unsupported compiler");
#endif
    }

    template <auto Value>
    constexpr auto EnumNameV = EnumName<Value>();
}

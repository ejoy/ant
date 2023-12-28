#pragma once

#include <string_view>

namespace ecs {
    constexpr auto component_name(std::string_view name) noexcept {
        for (std::size_t i = name.size(); i > 0; --i) {
            const char c = name[i - 1];
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c == '_'))) {
                name.remove_prefix(i);
                break;
            }
        }
        return name;
    }

    template <typename C>
    constexpr auto component_name() noexcept {
#if defined(_MSC_VER)
        return component_name({__FUNCSIG__, sizeof(__FUNCSIG__) - 17});
#else
        return component_name({__PRETTY_FUNCTION__, sizeof(__PRETTY_FUNCTION__) - 2});
#endif
    }

    template <typename T>
    constexpr auto component_name_v = component_name<T>();
}

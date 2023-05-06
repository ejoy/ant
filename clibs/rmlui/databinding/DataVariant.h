#pragma once

#include <string>
#include <optional>
#include "luavalue.h"

namespace Rml {
    using DataVariant = luavalue::value;

    namespace VariantHelper {
        template <typename T>
        bool Has(const DataVariant &variant) {
            return std::holds_alternative<T>(variant);
        }

        template <typename T>
        T Get(const DataVariant &variant) {
            if (const T *r = std::get_if<T>(&variant)) {
                return *r;
            }
            return T{};
        }

        template <typename T>
        T GetOpt(const DataVariant &variant, T def = T{}) {
            if (const T *r = std::get_if<T>(&variant)) {
                return *r;
            }
            return def;
        }

        template <typename T>
        T ConvertGet(const DataVariant &variant) {
            return std::visit([](auto const &val) {
                if constexpr (std::is_convertible_v<decltype(val), T>)
                    return T(val);
                else
                    return T{};
            }, variant);
        }

        inline std::string ToString(const DataVariant &variant) {
            return std::visit([](auto&& v) -> std::string {
                using T = std::decay_t<decltype(v)>;
                if constexpr (std::is_same_v<T, std::monostate>) {
                    return "";
                } else if constexpr (std::is_same_v<T, bool>) {
                    return v? "true": "false";
                } else if constexpr (std::is_same_v<T, void*>) {
                    return "";
                } else if constexpr (std::is_same_v<T, lua_Integer>) {
                    return std::to_string(v);
                } else if constexpr (std::is_same_v<T, lua_Number>) {
                    return std::to_string(v);
                } else if constexpr (std::is_same_v<T, std::string>) {
                    return v;
                } else if constexpr (std::is_same_v<T, lua_CFunction>) {
                    return "";
                } else {
                    static_assert(luavalue::always_false_v<T>, "non-exhaustive visitor!");
                }
            }, variant);
        }
        inline std::optional<std::string> ToStringOpt(const DataVariant &variant) {
            return std::visit([](auto&& v) -> std::optional<std::string> {
                using T = std::decay_t<decltype(v)>;
                if constexpr (std::is_same_v<T, std::monostate>) {
                    return std::nullopt;
                } else if constexpr (std::is_same_v<T, bool>) {
                    return v? "true": "false";
                } else if constexpr (std::is_same_v<T, void*>) {
                    return std::nullopt;
                } else if constexpr (std::is_same_v<T, lua_Integer>) {
                    return std::to_string(v);
                } else if constexpr (std::is_same_v<T, lua_Number>) {
                    return std::to_string(v);
                } else if constexpr (std::is_same_v<T, std::string>) {
                    return v;
                } else if constexpr (std::is_same_v<T, lua_CFunction>) {
                    return std::nullopt;
                } else {
                    static_assert(luavalue::always_false_v<T>, "non-exhaustive visitor!");
                }
            }, variant);
        }
    }

}

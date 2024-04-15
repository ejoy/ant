#pragma once

#include <lua.hpp>
#include <array>
#include <concepts>
#include <limits>
#include <map>
#include <string>
#include <string_view>
#include <utility>
#include <vector>
#include <bee/nonstd/unreachable.h>

namespace lua_struct {
    namespace reflection {
        template <unsigned short N>
        struct cstring {
            constexpr explicit cstring(std::string_view str) noexcept
                : cstring { str, std::make_integer_sequence<unsigned short, N> {} } {}
            constexpr const char* data() const noexcept { return chars_; }
            constexpr unsigned short size() const noexcept { return N; }
            constexpr operator std::string_view() const noexcept { return { data(), size() }; }
            template <unsigned short... I>
            constexpr cstring(std::string_view str, std::integer_sequence<unsigned short, I...>) noexcept
                : chars_ { str[I]..., '\0' } {}
            char chars_[static_cast<size_t>(N) + 1];
        };
        template <>
        struct cstring<0> {
            constexpr explicit cstring(std::string_view) noexcept {}
            constexpr const char* data() const noexcept { return nullptr; }
            constexpr unsigned short size() const noexcept { return 0; }
            constexpr operator std::string_view() const noexcept { return {}; }
        };

        template <typename T>
        struct wrapper { T a; };
        template <typename T>
        wrapper(T) -> wrapper<T>;

        template <typename T>
        static inline T storage = {};

        template <auto T>
        constexpr auto main_name_of_pointer()  {
            constexpr auto is_identifier = [](char c)
            { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_'; };
    #if __GNUC__ && (!__clang__) && (!_MSC_VER)
            std::string_view str = __PRETTY_FUNCTION__;
            std::size_t start = str.rfind("::") + 2;
            std::size_t end = start;
            for (; end < str.size() && is_identifier(str[end]); end++) {}
            return str.substr(start, end - start);
    #elif __clang__
            std::string_view str = __PRETTY_FUNCTION__;
            std::size_t start = str.rfind(".") + 1;
            std::size_t end = start;
            for (; end < str.size() && is_identifier(str[end]); end++) {}
            return str.substr(start, end - start);
    #elif _MSC_VER
            std::string_view str = __FUNCSIG__;
            std::size_t start = str.rfind("->") + 2;
            std::size_t end = start;
            for (; end < str.size() && is_identifier(str[end]); end++) {}
            return str.substr(start, end - start);
    #else
            static_assert(false, "Not supported compiler");
    #endif
        }

        struct any {
            constexpr any(int) {}
            template <typename T>
                requires std::is_copy_constructible_v<T>
            operator T&();
            template <typename T>
                requires std::is_move_constructible_v<T>
            operator T&&();
            template <typename T>
                requires(!std::is_copy_constructible_v<T> && !std::is_move_constructible_v<T>)
            operator T();
        };

        template <typename T, std::size_t N>
        constexpr std::size_t try_initialize_with_n() {
            return []<std::size_t... Is>(std::index_sequence<Is...>) { return requires { T{any(Is)...}; }; }(std::make_index_sequence<N>{});
        }

        template <typename T, std::size_t N = 0>
        constexpr auto field_count_impl() {
            if constexpr (try_initialize_with_n<T, N>() && !try_initialize_with_n<T, N + 1>()) {
                return N;
            }
            else {
                return field_count_impl<T, N + 1>();
            }
        }

        template <typename T>
            requires std::is_aggregate_v<T>
        static constexpr auto field_count = field_count_impl<T>();

#if defined(_MSC_VER)
#   pragma warning(push)
#   pragma warning(disable : 4101)
#endif

        template <typename T, std::size_t I>
        constexpr auto field_type_impl(T object) {
            constexpr auto N = field_count<T>;
            if constexpr (N == 0) {
                static_assert(N != 0, "the object has no fields");
            }
            else if constexpr (N == 1) {
                auto [v0] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0)>>>{};
            }
            else if constexpr (N == 2) {
                auto [v0, v1] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1)>>>{};
            }
            else if constexpr (N == 3) {
                auto [v0, v1, v2] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2)>>>{};
            }
            else if constexpr (N == 4) {
                auto [v0, v1, v2, v3] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3)>>>{};
            }
            else if constexpr (N == 5) {
                auto [v0, v1, v2, v3, v4] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4)>>>{};
            }
            else if constexpr (N == 6) {
                auto [v0, v1, v2, v3, v4, v5] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5)>>>{};
            }
            else if constexpr (N == 7) {
                auto [v0, v1, v2, v3, v4, v5, v6] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5), decltype(v6)>>>{};
            }
            else if constexpr (N == 8) {
                auto [v0, v1, v2, v3, v4, v5, v6, v7] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5), decltype(v6), decltype(v7)>>>{};
            }
            else if constexpr (N == 9) {
                auto [v0, v1, v2, v3, v4, v5, v6, v7, v8] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5), decltype(v6), decltype(v7), decltype(v8)>>>{};
            }
            else if constexpr (N == 10) {
                auto [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5), decltype(v6), decltype(v7), decltype(v8), decltype(v9)>>>{};
            }
            else if constexpr (N == 11) {
                auto [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5), decltype(v6), decltype(v7), decltype(v8), decltype(v9), decltype(v10)>>>{};
            }
            else if constexpr (N == 12) {
                auto [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5), decltype(v6), decltype(v7), decltype(v8), decltype(v9), decltype(v10), decltype(v11)>>>{};
            }
            else if constexpr (N == 13) {
                auto [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5), decltype(v6), decltype(v7), decltype(v8), decltype(v9), decltype(v10), decltype(v11), decltype(v12)>>>{};
            }
            else if constexpr (N == 14) {
                auto [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5), decltype(v6), decltype(v7), decltype(v8), decltype(v9), decltype(v10), decltype(v11), decltype(v12), decltype(v13)>>>{};
            }
            else if constexpr (N == 15) {
                auto [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5), decltype(v6), decltype(v7), decltype(v8), decltype(v9), decltype(v10), decltype(v11), decltype(v12), decltype(v13), decltype(v14)>>>{};
            }
            else if constexpr (N == 16) {
                auto [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15] = object;
                return std::type_identity<std::tuple_element_t<I, std::tuple<decltype(v0), decltype(v1), decltype(v2), decltype(v3), decltype(v4), decltype(v5), decltype(v6), decltype(v7), decltype(v8), decltype(v9), decltype(v10), decltype(v11), decltype(v12), decltype(v13), decltype(v14), decltype(v15)>>>{};
            }
            else {
                static_assert(N <= 16, "the max of supported fields is 16");
            }
        }

        template <std::size_t I>
        constexpr auto&& field_access(auto&& object) {
            using T = std::remove_cvref_t<decltype(object)>;
            constexpr auto N = field_count<T>;
            if constexpr (N == 0) {
                static_assert(N != 0, "the object has no fields");
            }
            else if constexpr (N == 1) {
                auto&& [v0] = object;
                return std::get<I> (std::forward_as_tuple(v0));
            }
            else if constexpr (N == 2) {
                auto&& [v0, v1] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1));
            }
            else if constexpr (N == 3) {
                auto&& [v0, v1, v2] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2));
            }
            else if constexpr (N == 4) {
                auto&& [v0, v1, v2, v3] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3));
            }
            else if constexpr (N == 5) {
                auto&& [v0, v1, v2, v3, v4] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4));
            }
            else if constexpr (N == 6) {
                auto&& [v0, v1, v2, v3, v4, v5] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5));
            }
            else if constexpr (N == 7) {
                auto&& [v0, v1, v2, v3, v4, v5, v6] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5, v6));
            }
            else if constexpr (N == 8) {
                auto&& [v0, v1, v2, v3, v4, v5, v6, v7] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5, v6, v7));
            }
            else if constexpr (N == 9) {
                auto&& [v0, v1, v2, v3, v4, v5, v6, v7, v8] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5, v6, v7, v8));
            }
            else if constexpr (N == 10) {
                auto&& [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9));
            }
            else if constexpr (N == 11) {
                auto&& [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10));
            }
            else if constexpr (N == 12) {
                auto&& [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11));
            }
            else if constexpr (N == 13) {
                auto&& [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12));
            }
            else if constexpr (N == 14) {
                auto&& [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13));
            }
            else if constexpr (N == 15) {
                auto&& [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14));
            }
            else if constexpr (N == 16) {
                auto&& [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15] = object;
                return std::get<I> (std::forward_as_tuple(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15));
            }
            else {
                static_assert(N <= 16, "the max of supported fields is 16");
            }
        }

#if defined(_MSC_VER)
#   pragma warning(pop)
#endif

        template <typename T, std::size_t I>
        constexpr auto field_name_impl() noexcept {
            constexpr auto name = main_name_of_pointer<wrapper{&field_access<I>(storage<T>)}>();
            return cstring<name.size()> { name };
        }

    
        template <typename T, std::size_t I>
            requires std::is_aggregate_v<T>
        using field_type = typename decltype(field_type_impl<T, I>(std::declval<T>()))::type;

        template <typename T, std::size_t I>
            requires std::is_aggregate_v<T>
        static constexpr auto field_name = field_name_impl<T, I>();
    }

    template <typename T, typename I>
    constexpr bool check_integral_limit(I i) {
        static_assert(std::is_integral_v<I>);
        static_assert(std::is_integral_v<T>);
        static_assert(sizeof(I) >= sizeof(T));
        if constexpr (sizeof(I) == sizeof(T)) {
            return true;
        }
        else if constexpr (std::numeric_limits<I>::is_signed == std::numeric_limits<T>::is_signed) {
            return i >= std::numeric_limits<T>::lowest() && i <= (std::numeric_limits<T>::max)();
        }
        else if constexpr (std::numeric_limits<I>::is_signed) {
            return static_cast<std::make_unsigned_t<I>>(i) >= std::numeric_limits<T>::lowest() && static_cast<std::make_unsigned_t<I>>(i) <= (std::numeric_limits<T>::max)();
        }
        else {
            return static_cast<std::make_signed_t<I>>(i) >= std::numeric_limits<T>::lowest() && static_cast<std::make_signed_t<I>>(i) <= (std::numeric_limits<T>::max)();
        }
    }

    template <typename T>
    T unpack(lua_State* L, int arg);

    template <typename T, std::size_t I>
    void unpack_struct(lua_State* L, int arg, T& v);

    template <typename T>
        requires(std::is_integral_v<T> && !std::same_as<T, bool>)
    T unpack(lua_State* L, int arg) {
        lua_Integer r = luaL_checkinteger(L, arg);
        if constexpr (std::is_same_v<T, lua_Integer>) {
            return r;
        }
        else if constexpr (sizeof(T) >= sizeof(lua_Integer)) {
            return static_cast<T>(r);
        }
        else {
            if (check_integral_limit<T>(r)) {
                return static_cast<T>(r);
            }
            luaL_error(L, "unpack integer limit exceeded", arg);
            std::unreachable();
        }
    }

    template <typename T>
        requires(std::same_as<T, bool>)
    T unpack(lua_State* L, int arg) {
        luaL_checktype(L, arg, LUA_TBOOLEAN);
        return !!lua_toboolean(L, arg);
    }

    template <typename T>
        requires std::is_pointer_v<T>
    T unpack(lua_State* L, int arg) {
        luaL_checktype(L, arg, LUA_TLIGHTUSERDATA);
        return static_cast<T>(lua_touserdata(L, arg));
    }

    template <>
    inline float unpack<float>(lua_State* L, int arg) {
        return (float)luaL_checknumber(L, arg);
    }

    template <>
    inline std::string unpack<std::string>(lua_State* L, int arg) {
        size_t sz = 0;
        const char* str = luaL_checklstring(L, arg, &sz);
        return std::string(str, sz);
    }

    template <>
    inline std::string_view unpack<std::string_view>(lua_State* L, int arg) {
        size_t sz = 0;
        const char* str = luaL_checklstring(L, arg, &sz);
        return std::string_view(str, sz);
    }

    template <typename T>
        requires std::is_aggregate_v<T>
    T unpack(lua_State* L, int arg) {
        T v;
        unpack_struct<T, 0>(L, arg, v);
        return v;
    }

    template<template<typename...> class Template, typename Class>
    struct is_instantiation : std::false_type {};
    template<template<typename...> class Template, typename... Args>
    struct is_instantiation<Template, Template<Args...>> : std::true_type {};
    template<typename Class, template<typename...> class Template>
    concept is_instantiation_of = is_instantiation<Template, Class>::value;

    template <typename T>
        requires is_instantiation_of<T, std::map>
    T unpack(lua_State* L, int arg) {
        arg = lua_absindex(L, arg);
        luaL_checktype(L, arg, LUA_TTABLE);
        T v;
        lua_pushnil(L);
        while (lua_next(L, arg)) {
            auto key = unpack<typename T::key_type>(L, -2);
            auto mapped = unpack<typename T::mapped_type>(L, -1);
            v.emplace(std::move(key), std::move(mapped));
            lua_pop(L, 1);
        }
        return v;
    }

    template <typename T>
        requires is_instantiation_of<T, std::vector>
    T unpack(lua_State* L, int arg) {
        arg = lua_absindex(L, arg);
        luaL_checktype(L, arg, LUA_TTABLE);
        lua_Integer n = luaL_len(L, arg);
        T v;
        v.reserve((size_t)n);
        for (lua_Integer i = 1; i <= n; ++i) {
            lua_geti(L, arg, i);
            auto value = unpack<typename T::value_type>(L, -1);
            v.emplace_back(std::move(value));
            lua_pop(L, 1);
        }
        return v;
    }

    template <typename T, std::size_t I>
    void unpack_struct(lua_State* L, int arg, T& v) {
        if constexpr (I < reflection::field_count<T>) {
            constexpr auto name = reflection::field_name<T, I>;
            lua_getfield(L, arg, name.data());
            reflection::field_access<I>(v) = unpack<reflection::field_type<T, I>>(L, -1);
            lua_pop(L, 1);
            unpack_struct<T, I + 1>(L, arg, v);
        }
    }

    template <typename T>
    void pack(lua_State* L, const T& v);

    template <typename T, std::size_t I>
    void pack_struct(lua_State* L, const T& v);

    template <typename T>
        requires(std::is_integral_v<T> && !std::same_as<T, bool>)
    void pack(lua_State* L, const T& v) {
        if constexpr (std::is_same_v<T, lua_Integer>) {
            lua_pushinteger(L, v);
        }
        else if constexpr (sizeof(T) <= sizeof(lua_Integer)) {
            lua_pushinteger(L, static_cast<lua_Integer>(v));
        }
        else {
            if (check_integral_limit<lua_Integer>(v)) {
                lua_pushinteger(L, static_cast<lua_Integer>(v));
            }
            luaL_error(L, "pack integer limit exceeded");
            std::unreachable();
        }
    }

    template <typename T>
        requires(std::same_as<T, bool>)
    void pack(lua_State* L, const T& v) {
        lua_pushboolean(L, v);
    }

    template <>
    inline void pack<float>(lua_State* L, const float& v) {
        lua_pushnumber(L, (lua_Number)v);
    }

    template <typename T>
        requires std::is_aggregate_v<T>
    void pack(lua_State* L, const T& v) {
        lua_createtable(L, 0, (int)reflection::field_count<T>);
        pack_struct<T, 0>(L, v);
    }

    template <typename T, std::size_t I>
    void pack_struct(lua_State* L, const T& v) {
        if constexpr (I < reflection::field_count<T>) {
            constexpr auto name = reflection::field_name<T, I>;
            pack<reflection::field_type<T, I>>(L, reflection::field_access<I>(v));
            lua_setfield(L, -2, name.data());
            pack_struct<T, I + 1>(L, v);
        }
    }
}

#pragma once

#include <array>
#include <cstdint>
#include <type_traits>

#include "util/variant.h"

struct lua_State;
struct luadbg_State;

namespace luadebug::refvalue {
    struct FRAME_LOCAL {
        uint16_t frame;
        int16_t n;
    };
    struct FRAME_FUNC {
        uint16_t frame;
    };
    struct GLOBAL {};
    enum class REGISTRY_TYPE {
        REGISTRY,
        DEBUG_REF,
        DEBUG_WATCH,
    };
    struct REGISTRY {
        REGISTRY_TYPE type;
    };
    struct STACK {
        int index;
    };
    struct UPVALUE {
        int n;
    };
    struct METATABLE {
        int type;
    };
    struct USERVALUE {
        int n;
    };
    struct TABLE_ARRAY {
        unsigned int index;
    };
    struct TABLE_HASH_KEY {
        unsigned int index;
    };
    struct TABLE_HASH_VAL {
        unsigned int index;
    };
    using value = variant<
        FRAME_LOCAL,
        FRAME_FUNC,
        GLOBAL,
        REGISTRY,
        STACK,
        UPVALUE,
        METATABLE,
        USERVALUE,
        TABLE_ARRAY,
        TABLE_HASH_KEY,
        TABLE_HASH_VAL>;
    static_assert(std::is_trivially_copyable_v<value>);

    template <typename T>
    struct allow_as_root : public std::false_type {};
    template <typename T>
    struct allow_as_child : public std::false_type {};

    template <>
    struct allow_as_root<FRAME_LOCAL> : public std::true_type {};
    template <>
    struct allow_as_root<FRAME_FUNC> : public std::true_type {};
    template <>
    struct allow_as_root<GLOBAL> : public std::true_type {};
    template <>
    struct allow_as_root<REGISTRY> : public std::true_type {};
    template <>
    struct allow_as_root<STACK> : public std::true_type {};
    template <>
    struct allow_as_root<METATABLE> : public std::true_type {};
    template <>
    struct allow_as_child<UPVALUE> : public std::true_type {};
    template <>
    struct allow_as_child<METATABLE> : public std::true_type {};
    template <>
    struct allow_as_child<USERVALUE> : public std::true_type {};
    template <>
    struct allow_as_child<TABLE_ARRAY> : public std::true_type {};
    template <>
    struct allow_as_child<TABLE_HASH_KEY> : public std::true_type {};
    template <>
    struct allow_as_child<TABLE_HASH_VAL> : public std::true_type {};

    int eval(value* v, lua_State* hL);
    bool assign(value* v, lua_State* hL);
    value* create_userdata(luadbg_State* L, int n);
    value* create_userdata(luadbg_State* L, int n, int parent);

    template <typename... Args>
    inline value* create(luadbg_State* L, int parent, Args&&... args) {
        constexpr auto N = sizeof...(Args);
        static_assert(N > 0);
        static_assert(std::conjunction_v<allow_as_child<Args>...>);
        using value_array = std::array<value, N>;
        auto v            = create_userdata(L, N, parent);
        new (reinterpret_cast<value_array*>(v)) value_array { std::forward<Args>(args)... };
        return v;
    }

    template <typename Tuple, size_t... Is>
    constexpr bool check_has_root(std::index_sequence<Is...>) {
        constexpr auto N = sizeof...(Is);
        return std::conjunction_v<std::conditional_t<
            Is == N - 1,
            allow_as_root<typename std::tuple_element<Is, Tuple>::type>,
            allow_as_child<typename std::tuple_element<Is, Tuple>::type>>...>;
    }
    template <typename... Args>
    constexpr bool check_has_root() {
        return check_has_root<std::tuple<Args...>>(std::make_index_sequence<sizeof...(Args)>());
    }

    template <typename... Args>
    inline value* create(luadbg_State* L, Args&&... args) {
        constexpr auto N = sizeof...(Args);
        static_assert(N > 0);
        static_assert(check_has_root<Args...>());
        using value_array = std::array<value, N>;
        auto v            = create_userdata(L, N);
        new (reinterpret_cast<value_array*>(v)) value_array { std::forward<Args>(args)... };
        return v;
    }
}

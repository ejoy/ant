#pragma once

#if !defined(_CRT_SECURE_NO_WARNINGS)
#define _CRT_SECURE_NO_WARNINGS
#endif

#include <lua.hpp>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>
#include <array>
#include <limits>

static_assert(sizeof(double) == sizeof(lua_Number));

namespace lua_struct {
    ///
    /// check
    ///
    namespace symbol {
        template <int tag = 0>
        struct stack {
            std::array<const char*, 16> data;
            size_t top = 0;
            void push(const char* name) {
                if (top > data.max_size()) {
                    return;
                }
                data[top++] = name;
            }
            void pop() {
                if (top == 0) {
                    return;
                }
                --top;
            }
        };
        stack stack_;
        struct guard {
            guard(const char* name) { stack_.push(name); }
            guard(size_t index) {
                if (index <= 0xFFFF) {
                    stack_.push((const char*)index);
                }
                else {
                    stack_.push("*");
                }
            }
            ~guard() { stack_.pop(); }
        };
        inline void result_add(luaL_Buffer* b, size_t idx) {
        }
        inline const char* result(lua_State* L) {
            if (stack_.top == 0) {
                return "";
            }
            luaL_Buffer b;
            luaL_buffinit(L, &b);
            for (size_t i = 0; i < stack_.top; ++i) {
                const char* s = stack_.data[i];
                if ((size_t)s <= 0xFFFF) {
                    luaL_addchar(&b, '[');
                    char* buff = luaL_prepbuffsize(&b, 10);
                    luaL_addsize(&b, l_sprintf(buff, 10, "%d", 1 + (int)(size_t)s));
                    luaL_addchar(&b, ']');
                }
                else {
                    luaL_addchar(&b, '.');
                    luaL_addstring(&b, s);
                }
            }
            luaL_pushresult(&b);
            return lua_tostring(L, -1);
        }
    }

    inline void raise(lua_State* L, const char* msg) {
        luaL_error(L, "bad argument '%s' (%s)", symbol::result(L), msg);
    }
    inline const char* gettype(lua_State* L, int idx) {
        if (luaL_getmetafield(L, idx, "__name") == LUA_TSTRING)
            return lua_tostring(L, -1);
        else if (lua_type(L, idx) == LUA_TLIGHTUSERDATA)
            return "light userdata";
        else
            return luaL_typename(L, idx);
    }
    inline void checkcond(lua_State* L, int cond, const char* msg) {
        if (!cond) {
            raise(L, msg);
        }
    }
    template <typename T, typename R>
    T checklimit(lua_State* L, R const& r) {
        if (r < std::numeric_limits<T>::lowest() || r > (std::numeric_limits<T>::max)()) {
            raise(L, "limit exceeded");
        }
        return (T)r;
    }
    inline void checktype(lua_State* L, int idx, int tag) {
        if (lua_type(L, idx) != tag) {
            raise(L, lua_pushfstring(L, "%s expected, got %s", lua_typename(L, tag), gettype(L, idx)));
        }
    }
    inline lua_Integer checkinteger(lua_State* L, int idx) {
        if (!lua_isinteger(L, idx)) {
            if (lua_isnumber(L, idx)) {
                raise(L, "number has no integer representation");
            }
            else {
                raise(L, lua_pushfstring(L, "%s expected, got %s", lua_typename(L, LUA_TNUMBER), gettype(L, idx)));
            }
        }
        return lua_tointeger(L, idx);
    }
    inline lua_Number checknumber(lua_State* L, int idx) {
        checktype(L, idx, LUA_TNUMBER);
        return lua_tonumber(L, idx);
    }
    inline const char* checkstring(lua_State* L, int idx) {
        checktype(L, idx, LUA_TSTRING);
        return lua_tostring(L, idx);
    }
    inline const char* checklstring(lua_State* L, int idx, size_t* len) {
        checktype(L, idx, LUA_TSTRING);
        return lua_tolstring(L, idx, len);
    }
    inline void* checkuserdata(lua_State* L, int idx) {
        if (lua_type(L, idx) != LUA_TLIGHTUSERDATA && lua_type(L, idx) != LUA_TUSERDATA) {
            raise(L, lua_pushfstring(L, "%s expected, got %s", lua_typename(L, LUA_TUSERDATA), gettype(L, idx)));
        }
        return lua_touserdata(L, idx);
    }

    ///
    /// unpack
    ///
    template <typename T>
    void unpack(lua_State* L, int idx, T& v, typename std::enable_if<!std::is_integral<T>::value>::type* = 0);

    template <typename T>
    void unpack(lua_State* L, int idx, T& v, typename std::enable_if<std::is_integral<T>::value>::type* = 0) {
        static_assert(sizeof(T) <= sizeof(lua_Integer));
        v = checklimit<T>(L, checkinteger(L, idx));
    }

    template <>
    void unpack<float>(lua_State* L, int idx, float& v, void*) {
        v = checklimit<float>(L, checknumber(L, idx));
    }

    template <>
    void unpack<double>(lua_State* L, int idx, double& v, void*) {
        v = (double)checknumber(L, idx);
    }

    template <>
    void unpack<bool>(lua_State* L, int idx, bool& v, void*) {
        v = !!lua_toboolean(L, idx);
    }

    template <>
    void unpack<std::string>(lua_State* L, int idx, std::string& v, void*) {
        size_t sz = 0;
        const char* str = checklstring(L, idx, &sz);
        v.assign(str, sz);
    }

    template <typename K, typename V>
    void unpack(lua_State* L, int idx, std::map<K, V>& v) {
        idx = lua_absindex(L, idx);
        checktype(L, idx, LUA_TTABLE);
        v.clear();
        lua_pushnil(L);
        while (lua_next(L, idx)) {
            symbol::guard guard("*"); //TODO
            std::pair<K, V> pair;
            unpack(L, -1, pair.second);
            lua_pop(L, 1);
            unpack(L, -1, pair.first);
            v.emplace(std::move(pair));
        }
    }

    template <typename K, typename V>
    void unpack(lua_State* L, int idx, std::unordered_map<K, V>& v) {
        idx = lua_absindex(L, idx);
        checktype(L, idx, LUA_TTABLE);
        v.clear();
        lua_pushnil(L);
        while (lua_next(L, idx)) {
            symbol::guard guard("*"); //TODO
            std::pair<K, V> pair;
            unpack(L, -1, pair.second);
            lua_pop(L, 1);
            unpack(L, -1, pair.first);
            v.emplace(std::move(pair));
        }
    }

    template <typename T>
    void unpack(lua_State* L, int idx, std::vector<T>& v) {
        checktype(L, idx, LUA_TTABLE);
        size_t n = (size_t)luaL_len(L, idx);
        v.resize(n);
        for (size_t i = 0; i < n; ++i) {
            symbol::guard guard(i);
            lua_geti(L, idx, (lua_Integer)(i + 1));
            unpack(L, -1, v[i]);
            lua_pop(L, 1);
        }
    }

    template <typename T, size_t N>
    void unpack(lua_State* L, int idx, std::array<T, N>& v) {
        checktype(L, idx, LUA_TTABLE);
        for (size_t i = 0; i < N; ++i) {
            symbol::guard guard(i);
            lua_geti(L, idx, (lua_Integer)(i + 1));
            unpack(L, -1, v[i]);
            lua_pop(L, 1);
        }
    }

    template <typename T, size_t N>
    void unpack(lua_State* L, int idx, T(&v)[N]) {
        checktype(L, idx, LUA_TTABLE);
        for (size_t i = 0; i < N; ++i) {
            symbol::guard guard(i);
            lua_geti(L, idx, (lua_Integer)(i + 1));
            unpack(L, -1, v[i]);
            lua_pop(L, 1);
        }
    }

    template <typename T>
    void unpack(lua_State* L, int idx, T*& v) {
        v = (T*)checkuserdata(L, idx);
    }

    template <typename T>
    void unpack(lua_State* L, int idx, T const*& v) {
        v = (T const*)checkuserdata(L, idx);
    }

    template <>
    void unpack<char>(lua_State* L, int idx, char const*& v) {
        v = checkstring(L, idx);
    }

    template <typename T>
    void unpack_field(lua_State* L, int idx, const char* name, T& v) {
        symbol::guard guard(name);
        lua_getfield(L, idx, name);
        unpack(L, -1, v);
        lua_pop(L, 1);
    }

    ///
    /// pack
    ///
    template <typename T>
    void pack(lua_State* L, T const& v, typename std::enable_if<!std::is_integral<T>::value>::type* = 0);

    template <typename T>
    void pack(lua_State* L, T const& v, typename std::enable_if<std::is_integral<T>::value>::type* = 0) {
        static_assert(sizeof(T) <= sizeof(lua_Integer));
        lua_pushinteger(L, (lua_Integer)v);
    }

    template <>
    void pack<float>(lua_State* L, float const& v, void*) {
        lua_pushnumber(L, (lua_Number)v);
    }

    template <>
    void pack<double>(lua_State* L, double const& v, void*) {
        lua_pushnumber(L, (lua_Number)v);
    }

    template <>
    void pack<bool>(lua_State* L, bool const& v, void*) {
        lua_pushboolean(L, v ? 1 : 0);
    }

    template <>
    void pack<std::string>(lua_State* L, std::string const& v, void*) {
        lua_pushlstring(L, v.data(), v.size());
    }

    template <typename K, typename V>
    void pack(lua_State* L, std::map<K, V> const& v) {
        lua_newtable(L);
        for (auto const& pair : v) {
            pack(L, pair.first);
            pack(L, pair.second);
            lua_settable(L, -3);
        }
    }

    template <typename K, typename V>
    void pack(lua_State* L, std::unordered_map<K, V> const& v) {
        lua_newtable(L);
        for (auto const& pair : v) {
            pack(L, pair.first);
            pack(L, pair.second);
            lua_settable(L, -3);
        }
    }

    template <typename T>
    void pack(lua_State* L, std::vector<T> const& v) {
        lua_newtable(L);
        for (size_t i = 0; i < v.size(); ++i) {
            pack(L, v[i]);
            lua_seti(L, -2, (lua_Integer)(i + 1));
        }
    }

    template <typename T, size_t N>
    void pack(lua_State* L, std::array<T, N> const& v) {
        lua_newtable(L);
        for (size_t i = 0; i < N; ++i) {
            pack(L, v[i]);
            lua_seti(L, -2, (lua_Integer)(i + 1));
        }
    }

    template <typename T, size_t N>
    void pack(lua_State* L, const T (&v)[N]) {
        lua_newtable(L);
        for (size_t i = 0; i < N; ++i) {
            pack(L, v[i]);
            lua_seti(L, -2, (lua_Integer)(i + 1));
        }
    }

    template <typename T>
    void pack(lua_State* L, T* const& v) {
        lua_pushlightuserdata(L, v);
    }

    template <typename T>
    void pack(lua_State* L, T const* const& v) {
        lua_pushlightuserdata(L, const_cast<T*>(v));
    }

    template <>
    void pack<char>(lua_State* L, char const* const& v) {
        lua_pushstring(L, v);
    }

    template <typename T>
    void pack_field(lua_State* L, const char* name, T const& v) {
        pack(L, v);
        lua_setfield(L, -2, name);
    }
}

#define LUA2STRUCT_EXPAND(args) args
#define LUA2STRUCT_PARAMS_COUNT(TAG,_16,_15,_14,_13,_12,_11,_10,_9,_8,_7,_6,_5,_4,_3,_2,_1,N,...) TAG##N

#define LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME) unpack_field((L), (IDX), #NAME, (V).NAME)
#define LUA2STRUCT_UNPACK_FIELD_1(L, IDX, V, NAME) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME)
#define LUA2STRUCT_UNPACK_FIELD_2(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_1(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_3(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_2(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_4(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_3(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_5(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_4(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_6(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_5(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_7(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_6(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_8(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_7(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_9(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_8(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_10(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_9(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_11(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_10(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_12(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_11(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_13(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_12(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_14(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_13(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_15(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_14(L, IDX, V, __VA_ARGS__))
#define LUA2STRUCT_UNPACK_FIELD_16(L, IDX, V, NAME, ...) LUA2STRUCT_UNPACK_FIELD_0(L, IDX, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_UNPACK_FIELD_15(L, IDX, V, __VA_ARGS__))


#define LUA2STRUCT_UNPACK(L, IDX, V, ...) LUA2STRUCT_EXPAND(LUA2STRUCT_PARAMS_COUNT(LUA2STRUCT_UNPACK_FIELD, __VA_ARGS__,_16,_15,_14,_13,_12,_11,_10,_9,_8,_7,_6,_5,_4,_3,_2,_1)(L, IDX, V, __VA_ARGS__))


#define LUA2STRUCT_PACK_FIELD_0(L, V, NAME) pack_field((L), #NAME, (V).NAME)
#define LUA2STRUCT_PACK_FIELD_1(L, V, NAME) LUA2STRUCT_PACK_FIELD_0(L, V, NAME)
#define LUA2STRUCT_PACK_FIELD_2(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_1(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_3(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_2(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_4(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_3(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_5(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_4(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_6(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_5(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_7(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_6(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_8(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_7(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_9(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_8(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_10(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_9(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_11(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_10(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_12(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_11(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_13(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_12(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_14(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_13(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_15(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_14(L, V, __VA_ARGS__))
#define LUA2STRUCT_PACK_FIELD_16(L, V, NAME, ...) LUA2STRUCT_PACK_FIELD_0(L, V, NAME); LUA2STRUCT_EXPAND(LUA2STRUCT_PACK_FIELD_15(L, V, __VA_ARGS__))

#define LUA2STRUCT_PACK(L, V, ...) LUA2STRUCT_EXPAND(LUA2STRUCT_PARAMS_COUNT(LUA2STRUCT_PACK_FIELD, __VA_ARGS__,_16,_15,_14,_13,_12,_11,_10,_9,_8,_7,_6,_5,_4,_3,_2,_1)(L, V, __VA_ARGS__))


#define LUA2STRUCT(STRUCT, ...) \
    namespace lua_struct { \
        template <> \
        void unpack<STRUCT>(lua_State* L, int idx, STRUCT& v, void*) { \
            luaL_checktype(L, idx, LUA_TTABLE); \
            LUA2STRUCT_UNPACK(L, idx, v, __VA_ARGS__); \
        }\
        template <> \
        void pack<STRUCT>(lua_State* L, STRUCT const& v, void*) { \
            lua_newtable(L); \
            LUA2STRUCT_PACK(L, v, __VA_ARGS__); \
        }\
    }

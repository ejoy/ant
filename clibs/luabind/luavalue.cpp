#include "luavalue.h"

namespace luavalue {
    void set(lua_State* L, int idx, value& v) {
        switch (lua_type(L, idx)) {
        case LUA_TNIL:
            v.emplace<std::monostate>();
            break;
        case LUA_TBOOLEAN:
            v.emplace<bool>(!!lua_toboolean(L, idx));
            break;
        case LUA_TLIGHTUSERDATA:
            v.emplace<void*>(lua_touserdata(L, idx));
            break;
        case LUA_TNUMBER:
            if (lua_isinteger(L, idx)) {
                v.emplace<lua_Integer>(lua_tointeger(L, idx));
            }
            else {
                v.emplace<lua_Number>(lua_tonumber(L, idx));
            }
            break;
        case LUA_TSTRING: {
            size_t sz = 0;
            const char* str = lua_tolstring(L, idx, &sz);
            v.emplace<std::string>(str, sz);
            break;
        }
        case LUA_TFUNCTION: {
            lua_CFunction func = lua_tocfunction(L, idx);
            if (func == NULL || lua_getupvalue(L, idx, 1) != NULL) {
                luaL_error(L, "Only light C function can be serialized");
                return;
            }
            v.emplace<lua_CFunction>(func);
            break;
        }
        default:
            luaL_error(L, "Unsupport type %s to serialize", lua_typename(L, idx));
        }
    }

    void set(lua_State* L, int idx, table& t) {
        luaL_checktype(L, idx, LUA_TTABLE);
        lua_pushnil(L);
        while (lua_next(L, idx)) {
            size_t sz = 0;
            const char* str = luaL_checklstring(L, -2, &sz);
            std::pair<std::string, value> pair;
            pair.first.assign(str, sz);
            set(L, -1, pair.second);
            t.emplace(pair);
            lua_pop(L, 1);
        }
    }

    void get(lua_State* L, const value& v) {
        std::visit([=](auto&& arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, std::monostate>) {
                lua_pushnil(L);
            } else if constexpr (std::is_same_v<T, bool>) {
                lua_pushboolean(L, arg);
            } else if constexpr (std::is_same_v<T, void*>) {
                lua_pushlightuserdata(L, arg);
            } else if constexpr (std::is_same_v<T, lua_Integer>) {
                lua_pushinteger(L, arg);
            } else if constexpr (std::is_same_v<T, lua_Number>) {
                lua_pushnumber(L, arg);
            } else if constexpr (std::is_same_v<T, std::string>) {
                lua_pushlstring(L, arg.data(), arg.size());
            } else if constexpr (std::is_same_v<T, lua_CFunction>) {
                lua_pushcfunction(L, arg);
            } else {
                static_assert(always_false_v<T>, "non-exhaustive visitor!");
            }
        }, v);
    }

    void get(lua_State* L, const table& t) {
        lua_createtable(L, 0, static_cast<int>(t.size()));
        for (const auto& [k, v] : t) {
            lua_pushlstring(L, k.data(), k.size());
            get(L, v);
            lua_rawset(L, -3);
        }
    }
}

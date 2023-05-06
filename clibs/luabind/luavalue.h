#pragma once

#include <lua.hpp>
#include <string>
#include <variant>
#include <map>

namespace luavalue {
    template<class> inline constexpr bool always_false_v = false;

    using value = std::variant<
        std::monostate, // LUA_TNIL
        bool,           // LUA_TBOOLEAN
        void*,          // LUA_TLIGHTUSERDATA
        lua_Integer,    // LUA_TNUMBER
        lua_Number,     // LUA_TNUMBER
        std::string,    // LUA_TSTRING
        lua_CFunction   // LUA_TFUNCTION
    >;
    using table = std::map<std::string, value>;

    void set(lua_State* L, int idx, value& v);
    void set(lua_State* L, int idx, table& v);
    void get(lua_State* L, const value& v);
    void get(lua_State* L, const table& v);
}

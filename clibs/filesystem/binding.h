#pragma once

#include "unicode.h"
#include <lua.hpp>

namespace ant::lua {
#if defined(_WIN32)
    typedef std::wstring string_type;
#else
    typedef std::string string_type;
#endif

#if defined(_WIN32)
    inline std::wstring to_string(lua_State* L, int idx) {
        size_t len = 0;
        const char* buf = luaL_checklstring(L, idx, &len);
        return u2w(std::string_view(buf, len));
    }
#else
    inline std::string to_string(lua_State* L, int idx) {
        size_t len = 0;
        const char* buf = luaL_checklstring(L, idx, &len);
        return std::string(buf, len);
    }
#endif

    template <class T>
    inline T tostring(lua_State* L, int idx);

    template <>
    inline std::string tostring<std::string>(lua_State* L, int idx) {
        size_t len = 0;
        const char* buf = luaL_checklstring(L, idx, &len);
        return std::string(buf, len);
    }

#if defined(_WIN32)
    template <>
    inline std::wstring tostring<std::wstring>(lua_State* L, int idx) {
        size_t len = 0;
        const char* buf = luaL_checklstring(L, idx, &len);
        return u2w(std::string_view(buf, len));
    }
#endif
}

#define LUA_TRY     try {
    
#if defined(_MSC_VER)
#define LUA_TRY_END } catch (const std::exception& e) { \
        lua_pushstring(L, a2u(e.what()).c_str()); \
        return lua_error(L); \
    }
#else
#define LUA_TRY_END } catch (const std::exception& e) { \
        lua_pushstring(L, e.what()); \
        return lua_error(L); \
    }
#endif

#if defined(_WIN32)
#define ANT_LUA_API extern "C" __declspec(dllexport)
#else
#define ANT_LUA_API extern "C"
#endif

#define newObject(L, name)      luaL_newmetatable((L), "ant::" name)
#define getObject(L, idx, name) luaL_checkudata((L), (idx), "ant::" name)

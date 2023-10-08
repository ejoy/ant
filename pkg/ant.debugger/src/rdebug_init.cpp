#if defined(_MSC_VER)

#    include <lua.hpp>

#    include "rdebug_win32.h"

extern "C" __declspec(dllexport) int init(lua_State* hL) {
    luadebug::win32::caller_is_luadll(_ReturnAddress());
    if (lua_type(hL, 1) == LUA_TSTRING) {
        luadebug::win32::set_luaapi(*(void**)lua_tostring(hL, -1));
    }
    else {
        luadebug::win32::set_luaapi(nullptr);
    }
    return 0;
}

#endif

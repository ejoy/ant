#include <lua.h>
#include <lauxlib.h>
#include <bx/platform.h>

int los(lua_State* L) {
    lua_pushstring(L, BX_PLATFORM_NAME);
    return 1;
}

#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_platform(lua_State* L) {
    static luaL_Reg lib[] = {
        { "os", los },
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    return 1;
}


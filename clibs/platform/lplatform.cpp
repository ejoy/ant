#include <lua.hpp>
#include <bx/platform.h>

int lfont(lua_State* L);

extern "C"
#if BX_PLATFORM_WINDOWS
__declspec(dllexport)
#endif
int luaopen_platform(lua_State* L) {
    static luaL_Reg lib[] = {
#if BX_PLATFORM_WINDOWS || BX_PLATFORM_OSX || BX_PLATFORM_LINUX
        { "font", lfont },
#endif
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    return 1;
}

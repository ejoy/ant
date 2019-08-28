#include <lua.hpp>
#include <bx/platform.h>


#if defined(_WIN32)
int linit_dpi(lua_State* L);
#endif
int ldpi(lua_State* L);
int lfont(lua_State* L);
int linfo(lua_State* L);

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_platform(lua_State* L) {
    static luaL_Reg lib[] = {
#if defined(_WIN32)
        { "init_dpi", linit_dpi },
#endif
        { "info", linfo },
        { "font", lfont },
        { "dpi", ldpi },
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    lua_pushstring(L, BX_PLATFORM_NAME);
    lua_setfield(L, -2, "OS");
    lua_pushstring(L, BX_CRT_NAME);
    lua_setfield(L, -2, "CRT");
    return 1;
}

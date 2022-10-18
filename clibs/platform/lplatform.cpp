#include <lua.hpp>
#include <bx/platform.h>


#if BX_PLATFORM_WINDOWS
int linit_dpi(lua_State* L);
#endif
int ldpi(lua_State* L);
int lfont(lua_State* L);
int linfo(lua_State* L);
#if BX_PLATFORM_IOS
int lsetting(lua_State* L);
int lmachine(lua_State* L);
bool isiOSAppOnMac();
#endif

extern "C"
#if BX_PLATFORM_WINDOWS
__declspec(dllexport)
#endif
int luaopen_platform(lua_State* L) {
    static luaL_Reg lib[] = {
#if BX_PLATFORM_WINDOWS
        { "init_dpi", linit_dpi },
#endif
        { "info", linfo },
        { "font", lfont },
        { "dpi", ldpi },
#if BX_PLATFORM_IOS
        { "setting", lsetting },
        { "machine", lmachine },
#endif
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    return 1;
}

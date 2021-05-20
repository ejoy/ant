#define LUA_LIB 1
#include <lua.hpp>

#ifdef USE_BGFX
#define EXPORT_BGFX_INTERFACE
#include "../bgfx/bgfx_interface.h"
#endif //USE_BGFX

#define LIGHTMAPPER_IMPLEMENTATION
#include "lightmapping.h"


static int
lbake_lightmap(lua_State *L){
    return 1;
}

extern "C"{
LUAMOD_API int
luaopen_bake(lua_State* L) {
    luaL_Reg lib[] = {
        { "bake_lightmap", lbake_lightmap},
        { nullptr, nullptr },
    };
    luaL_newlib(L, lib);
    return 1;
}
}
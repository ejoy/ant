#include "lua.hpp"

extern "C"{
LUAMOD_API int
luaopen_bake2(lua_State* L) {
    luaL_Reg lib[] = {
        { nullptr, nullptr },
    };
    luaL_newlib(L, lib);
    return 1;
}
}
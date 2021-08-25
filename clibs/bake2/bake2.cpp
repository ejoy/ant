#include "lua.hpp"
#include "BakerInterface.h"

static int
lcreate_baker(lua_State *L){
    Scene s;
    BakerHandle bh = CreateBaker(&s);
    lua_pushlightuserdata(L, bh);
    return 1;
}

static int
lbake(lua_State *L){
    auto bh = (BakerHandle)lua_touserdata(L, 1);
    BakeResult br;
    Bake(bh, &br);
    lua_createtable(L, 0, 0);
    lua_pushlstring(L, (const char*)br.lm.data.data(), br.lm.data.size());
    lua_setfield(L, -2, "data");

    lua_pushinteger(L, br.lm.size);
    lua_setfield(L, -2, "sieze");

    lua_pushinteger(L, br.lm.texelsize);
    lua_setfield(L, -2, "texelsize");
    return 1;
}

static int
ldestory_baker(lua_State *L){
    auto bh = (BakerHandle)lua_touserdata(L, 1);
    DestoryBaker(bh);
    return 0;
}

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
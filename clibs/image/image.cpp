#include <lua.hpp>

#include "bimg/decode.h"

static int
lparse(lua_State *L){
    bimg::imageParse(nullptr, nullptr, 1);
    return 1;
}

int luaopen_image(lua_State* L) {
    luaL_Reg lib[] = {
        { "parse", lparse},
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    return 1;
}
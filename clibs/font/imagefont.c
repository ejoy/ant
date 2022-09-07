#define LUA_LIB
#include <lua.h>

#include "imagefont.h"


LUAMOD_API int
luaopen_font_image(lua_State *L) {
    luaL_checkversion(L);

	lua_newtable(L);
	lua_pushvalue(L, -1);
	lua_setfield(L, LUA_REGISTRYINDEX, IMAGE_FONT);

    return 1;
}
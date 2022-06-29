#define LUA_LIB
#include <lua.h>
#include <lauxlib.h>

LUAMOD_API int
luaopen_scene_core(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}


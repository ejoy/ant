#define LUA_LIB

#include <bx/timer.h>

extern "C"{

#include <lua.h>
#include <lauxlib.h>

}

static int
lgetHPCounter(lua_State *L){
	int64_t i64 = bx::getHPCounter();
	lua_pushinteger(L, i64);
	return 1;
}

static int
lgetHPFrequency(lua_State *L){
	int64_t i64 = bx::getHPFrequency();
	lua_pushinteger(L, i64);
	return 1;
}

static int
lgetPlatformName(lua_State *L){
	lua_pushstring(L, BX_PLATFORM_NAME);
	return 1;
}

extern "C" {

LUAMOD_API int
luaopen_bgfx_baselib(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "HP_counter", lgetHPCounter},
		{ "HP_frequency", lgetHPFrequency},
		{ "platform_name", lgetPlatformName},
		{ NULL, NULL },
	};

	luaL_newlib(L,l);
	return 1;
}

}

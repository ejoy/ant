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
lgetHPTime(lua_State *L) {
	int64_t c = bx::getHPCounter();
	int64_t t = bx::getHPFrequency();
	double time = (double)c/(double)t;
	lua_pushnumber(L, time);
	return 1;
}

extern "C" {

LUAMOD_API int
luaopen_bgfx_baselib(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "HP_counter", lgetHPCounter},
		{ "HP_time", lgetHPTime},
		{ NULL, NULL },
	};

	luaL_newlib(L,l);
	lua_pushstring(L, BX_PLATFORM_NAME);
	lua_setfield(L, -2, "platform_name");
	int64_t i64 = bx::getHPFrequency();
	lua_pushinteger(L, i64);
	lua_setfield(L, -2, "HP_frequency");
	return 1;
}

}

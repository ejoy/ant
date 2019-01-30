#define LUA_LIB

#include <bx/timer.h>
#include <string.h>

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
lgetHPTime(lua_State *L){
	int64_t f = bx::getHPFrequency();
	int64_t l = lua_tointeger(L, 1);

	const double t = (l / (double)f) * 1000.f;
	lua_pushnumber(L, t);
	return 1;
}

static int
lgetHPDeltaTime(lua_State *L) {
	int64_t c = bx::getHPCounter();
	int64_t f = bx::getHPFrequency();

	int64_t l = lua_tointeger(L, 1);

	double time = ((c - l) / (double)f) * 1000.f;	// 1000 for ms
	lua_pushnumber(L, time);
	return 1;
}

extern "C" {

LUAMOD_API int
luaopen_bgfx_baselib(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "HP_counter",		lgetHPCounter},
		{ "HP_deltatime",	lgetHPDeltaTime},
		{ "HP_time",		lgetHPTime},
		{ NULL, NULL },
	};

	luaL_newlib(L,l);
	int64_t i64 = bx::getHPFrequency();
	lua_pushinteger(L, i64);
	lua_setfield(L, -2, "HP_frequency");
	return 1;
}

}

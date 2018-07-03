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
lgetHPTime(lua_State *L) {
	int64_t c = bx::getHPCounter();
	int64_t t = bx::getHPFrequency();

	const char* unit = lua_type(L, 1) == LUA_TSTRING ? lua_tostring(L, 1) : "ms";
	double time = ((double)c / (double)t) * 1000;
	if (strcmp(unit, "ms") == 0)
		time *= 1000;
	
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

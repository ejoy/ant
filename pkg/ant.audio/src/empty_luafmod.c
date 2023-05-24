#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>

static int
laudio_shutdown(lua_State *L) {
	return 0;
}

static int
laudio_load_bank(lua_State *L) {
	return 0;
}

static int
laudio_unload_bank(lua_State *L) {
	return 0;
}

static int
laudio_unload_all(lua_State *L) {
	return 0;
}

static int
laudio_update(lua_State *L) {
	return 0;
}

static int
laudio_event_get(lua_State *L) {
	return 0;
}

static int
laudio_event_play(lua_State *L) {
	return 0;
}

static int
lbackground_play(lua_State *L) {
	return 0;
}

static int
lbackground_stop(lua_State *L) {
	return 0;
}

static int
laudio_background(lua_State *L) {
	lua_newtable(L);
	if (luaL_newmetatable(L, "AUDIO_BACKGROUND")) {
		luaL_Reg l[] = {
			{ "__index", NULL },
			{ "play", lbackground_play },
			{ "stop", lbackground_stop },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
	return 0;
}

static int
laudio_init(lua_State *L) {
	lua_newtable(L);
	if (luaL_newmetatable(L, "AUDIO_FMOD")) {
		luaL_Reg l[] = {
			{ "__index", NULL },
			{ "shutdown", laudio_shutdown },
			{ "load_bank", laudio_load_bank },
			{ "unload_bank", laudio_unload_bank },
			{ "unload_all", laudio_unload_all },
			{ "update", laudio_update },
			{ "event_get",  laudio_event_get },
			{ "background", laudio_background },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

LUAMOD_API int
luaopen_fmod(lua_State * L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", laudio_init },
		{ "play", laudio_event_play },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

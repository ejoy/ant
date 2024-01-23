#include <lua.hpp>
#include <stdio.h>
#include "../window.h"


static void
update_callback(struct ant_window_callback* cb) {
	lua_State* L = cb->updateL;
	lua_pushvalue(L, 2);
	if (lua_pcall(L, 0, 0, 1) != LUA_OK) {
		printf("Error: %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
}

static int
ltraceback(lua_State *L) {
	const char *msg = lua_tostring(L, 1);
	if (msg == NULL && !lua_isnoneornil(L, 1)) {
		lua_pushvalue(L, 1);
	} else {
		luaL_traceback(L, L, msg, 2);
	}
	return 1;
}

static int
linit(lua_State *L) {
	struct ant_window_callback* cb = (struct ant_window_callback*)lua_newuserdatauv(L, sizeof(*cb), 2);
	cb->update = update_callback;
	cb->messageL = lua_newthread(L);
	lua_setiuservalue(L, -2, 1);
	cb->updateL = lua_newthread(L);
	lua_setiuservalue(L, -2, 2);
	lua_setfield(L, LUA_REGISTRYINDEX, "ANT_WINDOW_CONTEXT");

	lua_pushvalue(L, 1);
	lua_xmove(L, cb->messageL, 1);

	lua_pushcfunction(cb->updateL, ltraceback);
	lua_pushvalue(L, 2);
	lua_xmove(L, cb->updateL, 1);

	loopwindow_init(cb);
	return 0;
}

static int
lmainloop(lua_State *L) {
	loopwindow_mainloop();
	return 0;
}

static int
lmaxfps(lua_State *L) {
	float fps = (float)luaL_checknumber(L, 1);
	window_maxfps(fps);
	return 0;
}

extern "C" int
luaopen_window(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", linit },
		{ "mainloop", lmainloop },
		{ "maxfps", lmaxfps },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

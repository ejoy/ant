#include <lua.hpp>
#include "../window.h"

static int linit(lua_State *L) {
	struct ant_window_callback* cb = (struct ant_window_callback*)lua_newuserdatauv(L, sizeof(*cb), 1);
	cb->messageL = lua_newthread(L);
	lua_setiuservalue(L, -2, 1);
	lua_setfield(L, LUA_REGISTRYINDEX, "ANT_WINDOW_CONTEXT");

	lua_pushvalue(L, 1);
	lua_xmove(L, cb->messageL, 1);

	const char * size = lua_tostring(L, 2);

	void* window = peekwindow_init(cb, size);
	if (!window) {
		return luaL_error(L, "window init failed");
	}
	lua_pushlightuserdata(L, window);
	return 1;
}

static int lclose(lua_State *L) {
	peekwindow_close();
	return 0;
}

static int lpeekmessage(lua_State *L) {
	lua_pushboolean(L, peekwindow_peekmessage());
	return 1;
}

static int lsetcursor(lua_State* L) {
	lua_Integer cursor = luaL_checkinteger(L, 1);
	peekwindow_setcursor((int)cursor);
	return 0;
}

extern "C" int
luaopen_window(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", linit },
		{ "close", lclose },
		{ "peekmessage", lpeekmessage },
		{ "setcursor", lsetcursor },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

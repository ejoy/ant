#include <lua.hpp>
#include "../window.h"

static int
linit(lua_State *L) {
	struct ant_window_callback* cb = (struct ant_window_callback*)lua_newuserdatauv(L, sizeof(*cb), 1);
	cb->messageL = lua_newthread(L);
	lua_setiuservalue(L, -2, 1);
	lua_setfield(L, LUA_REGISTRYINDEX, "ANT_WINDOW_CONTEXT");

	lua_pushvalue(L, 1);
	lua_xmove(L, cb->messageL, 1);

	const char * size = lua_tostring(L, 2);

	if (0 != window_init(cb, size)) {
		return luaL_error(L, "window init failed");
	}
	return 0;
}

static int
lclose(lua_State *L) {
	window_close();
	return 0;
}

static int
lpeekmessage(lua_State *L) {
	lua_pushboolean(L, window_peekmessage());
	return 1;
}

extern "C" int
luaopen_window(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", linit },
		{ "close", lclose },
		{ "peekmessage", lpeekmessage },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

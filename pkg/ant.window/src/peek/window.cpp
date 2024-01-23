#include <lua.hpp>
#include "../window.h"

static bee::zstring_view lua_checkstrview(lua_State* L, int idx) {
	size_t sz = 0;
	const char* str = luaL_checklstring(L, idx, &sz);
	return { str, sz };
}

static int init(lua_State *L) {
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

static int close(lua_State *L) {
	peekwindow_close();
	return 0;
}

static int peek_message(lua_State *L) {
	lua_pushboolean(L, peekwindow_peek_message());
	return 1;
}

static int set_cursor(lua_State* L) {
	lua_Integer cursor = luaL_checkinteger(L, 1);
	peekwindow_set_cursor((int)cursor);
	return 0;
}

static int set_title(lua_State* L) {
	auto title = lua_checkstrview(L, 1);
	peekwindow_set_title(title);
	return 0;
}

extern "C" int
luaopen_window(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", init },
		{ "close", close },
		{ "peek_message", peek_message },
		{ "set_cursor", set_cursor },
		{ "set_title", set_title },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

#include <lua.hpp>
#include "window.h"

static bee::zstring_view lua_checkstrview(lua_State* L, int idx) {
	size_t sz = 0;
	const char* str = luaL_checklstring(L, idx, &sz);
	return { str, sz };
}

static int init(lua_State* L) {
	lua_State* messageL = lua_newthread(L);
	lua_setfield(L, LUA_REGISTRYINDEX, "ANT_WINDOW_MESSAGE");
	lua_pushvalue(L, 1);
	lua_xmove(L, messageL, 1);

	const char* size = lua_tostring(L, 2);
	bool ok = window_init(messageL, size);
	if (!ok) {
		return luaL_error(L, "window init failed");
	}
	return 0;
}

static int close(lua_State *L) {
	window_close();
	return 0;
}

static int peek_message(lua_State *L) {
	lua_pushboolean(L, window_peek_message());
	return 1;
}

static int set_cursor(lua_State* L) {
	lua_Integer cursor = luaL_checkinteger(L, 1);
	window_set_cursor((int)cursor);
	return 0;
}

static int show_cursor(lua_State* L) {
	bool show = lua_toboolean(L, 1);
	window_show_cursor(show);
	lua_pop(L, 1);
	return 0;
}

static int set_title(lua_State* L) {
	auto title = lua_checkstrview(L, 1);
	window_set_title(title);
	return 0;
}

static int set_maxfps(lua_State *L) {
	float fps = (float)luaL_checknumber(L, 1);
	window_set_maxfps(fps);
	return 0;
}

static int set_fullscreen(lua_State *L) {
	bool fs = lua_toboolean(L, 1);
	lua_pop(L, 1);
	window_set_fullscreen(fs);
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
		{ "show_cursor", show_cursor },
		{ "set_title", set_title },
		{ "set_maxfps", set_maxfps },
		{ "set_fullscreen", set_fullscreen },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

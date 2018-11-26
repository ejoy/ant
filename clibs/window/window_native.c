#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include "window_native.h"

static void
default_message_handle(void *ud, struct ant_window_message *msg) {
	// dummy handle
	(void)ud;
	printf("Unhandle message %d\n", msg->type);
}

/*
	integer width
	integer height
	string title

	return lud HWND
 */
static int
lcreatewindow(lua_State *L) {
	int width = (int)luaL_checkinteger(L, 1);
	int height = (int)luaL_checkinteger(L, 2);
	size_t sz;
	const char* title = luaL_checklstring(L, 3, &sz);
	struct ant_window_callback* cb = lua_newuserdata(L, sizeof(*cb));
	cb->ud = NULL;
	cb->message = default_message_handle;
	lua_setfield(L, LUA_REGISTRYINDEX, ANT_WINDOW_CALLBACK);
	void* wnd = window_create(width, height, title, sz);
	if (wnd == NULL) {
		return luaL_error(L, "Create window failed");
	}
	lua_pushlightuserdata(L, wnd);
	return 1;
}

static int
lmainloop(lua_State *L) {
	if (lua_getfield(L, LUA_REGISTRYINDEX, ANT_WINDOW_CALLBACK) != LUA_TUSERDATA) {
		return luaL_error(L, "Create native window first");
	}
	struct ant_window_callback* cb = lua_touserdata(L, -1);
	lua_pop(L, 1);
	window_mainloop(cb);
	return 0;
}

LUAMOD_API int
luaopen_window_native(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create", lcreatewindow },
		{ "mainloop", lmainloop },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

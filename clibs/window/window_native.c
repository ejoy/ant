#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include "window_native.h"

static void
default_message_handle(void *ud, struct ant_window_message *msg) {
	// dummy handle
	(void)ud;
	//printf("Unhandle message %d\n", msg->type);
}

static struct ant_window_callback*
get_callback(lua_State *L) {
	if (lua_getfield(L, LUA_REGISTRYINDEX, ANT_WINDOW_CALLBACK) != LUA_TUSERDATA) {
		luaL_error(L, "Can't find ant_window_callback.");
		return 0;
	}
	return (struct ant_window_callback*)lua_touserdata(L, -1);
}

/*
	integer width
	integer height
	string title
 */
static int
lcreatewindow(lua_State *L) {
	int width = (int)luaL_optinteger(L, 1, 1334);
	int height = (int)luaL_optinteger(L, 2, 750);
	size_t sz;
	const char* title = luaL_optlstring(L, 3, "Ant", &sz);
	if (0 != window_create(get_callback(L), width, height, title, sz)) {
		return luaL_error(L, "Create window failed");
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int
lmainloop(lua_State *L) {
	window_mainloop(get_callback(L));
	return 0;
}

static void
init(lua_State *L) {
	struct ant_window_callback* cb = lua_newuserdata(L, sizeof(*cb));
	cb->ud = NULL;
	cb->message = default_message_handle;
	lua_setfield(L, LUA_REGISTRYINDEX, ANT_WINDOW_CALLBACK);
	window_init(cb);
}

LUAMOD_API int
luaopen_window_native(lua_State *L) {
	init(L);
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create", lcreatewindow },
		{ "mainloop", lmainloop },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

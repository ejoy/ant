#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include "window_native.h"
#include "virtual_keys.h"

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

static void
init_keymap(lua_State *L) {
	typedef struct {
		int code;
		const char* name;
	} keymap_t;
	static keymap_t keymap[] = {
		{VK_TAB, "Tab"},
		{VK_LEFT, "Left"},
		{VK_RIGHT, "Right"},
		{VK_UP, "Up"},
		{VK_DOWN, "Down"},
		{VK_PRIOR, "PageUp"},
		{VK_NEXT, "PageDown"},
		{VK_HOME, "Home"},
		{VK_END, "End"},
		{VK_INSERT, "Insert"},
		{VK_DELETE, "Delete"},
		{VK_BACK, "Backspace"},
		{VK_SPACE, "Space"},
		{VK_RETURN, "Enter"},
		{VK_ESCAPE, "Escape"},
	};
	lua_createtable(L, 0, sizeof(keymap) / sizeof(keymap[0]));
	for (size_t i = 0; i < sizeof(keymap) / sizeof(keymap[0]); ++i) {
		lua_pushinteger(L, keymap[i].code);
		lua_setfield(L, -2, keymap[i].name);
	}
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

	init_keymap(L);
	lua_setfield(L, -2, "keymap");

	return 1;
}

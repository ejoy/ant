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

static int
window_keymap(int whatkey) {
	static const int keymap[ANT_KEYMAP_COUNT] = {
		VK_TAB,
		VK_LEFT,
		VK_RIGHT,
		VK_UP,
		VK_DOWN,
		VK_PRIOR,
		VK_NEXT,
		VK_HOME,
		VK_END,
		VK_INSERT,
		VK_DELETE,
		VK_BACK,
		VK_SPACE,
		VK_RETURN,
		VK_ESCAPE,
	};
	if (whatkey < 0 || whatkey >= ANT_KEYMAP_COUNT)
		return -1;
	return keymap[whatkey];
}

static void
init_keymap(lua_State *L) {
	static const char * name[ANT_KEYMAP_COUNT] = {
		"Tab",
		"Left",
		"Right",
		"Up",
		"Down",
		"PageUp",
		"PageDown",
		"Home",
		"End",
		"Insert",
		"Delete",
		"Backspace",
		"Space",
		"Enter",
		"Escape",
	};
	lua_createtable(L, 0, ANT_KEYMAP_COUNT);
	int i;
	for (i=0;i<ANT_KEYMAP_COUNT;i++) {
		int c = window_keymap(i);
		if (c >= 0) {
			lua_pushinteger(L, c);
			lua_setfield(L, -2, name[i]);
		}
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

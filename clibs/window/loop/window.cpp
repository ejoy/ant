#include <stdio.h>
#include <lua.hpp>
#include <stdint.h>
#include <assert.h>
#include "../window.h"
#include "../virtual_keys.h"
#ifdef _WIN32
#include <windows.h>
#include <WinNT.h>
#endif //_WIN32

extern "C" {
#include <lua-seri.h>
}

static void
push_exit_args(lua_State *L, struct ant_window_exit *exit) {
}

static void
push_keyboard_arg(lua_State *L, struct ant_window_keyboard *keyboard) {
	lua_pushinteger(L, keyboard->key);
	lua_pushinteger(L, keyboard->press);
	lua_pushinteger(L, keyboard->state);
}

static void
push_mouse_wheel_args(lua_State *L, struct ant_window_mouse_wheel *mouse) {
	lua_pushinteger(L, mouse->x);
	lua_pushinteger(L, mouse->y);
	lua_pushnumber(L, mouse->delta);
}

static void
push_mouse_arg(lua_State *L, struct ant_window_mouse *mouse) {
	lua_pushinteger(L, mouse->x);
	lua_pushinteger(L, mouse->y);
	lua_pushinteger(L, mouse->type);
	lua_pushinteger(L, mouse->state);
}

static void
push_size_arg(lua_State *L, struct ant_window_size *size) {
	lua_pushinteger(L, size->x);
	lua_pushinteger(L, size->y);
	lua_pushinteger(L, size->type);
}

static void
push_char_arg(lua_State *L, struct ant_window_char *c) {
	lua_pushinteger(L, c->code);
}

static int
push_arg(lua_State *L, struct ant_window_message *msg) {
	switch(msg->type) {
	case ANT_WINDOW_INIT:
		lua_pushstring(L, "init");
		push_init_args(L, &msg->u.init);
		break;
	case ANT_WINDOW_RECREATE:
		lua_pushstring(L, "recreate");
		push_init_args(L, &msg->u.init);
		break;
	case ANT_WINDOW_EXIT:
		lua_pushstring(L, "exit");
		push_exit_args(L, &msg->u.exit);
		break;
	case ANT_WINDOW_TOUCH:
		break;
	case ANT_WINDOW_KEYBOARD:
		lua_pushstring(L, "keyboard");
		push_keyboard_arg(L, &msg->u.keyboard);
		break;
	case ANT_WINDOW_MOUSE_WHEEL:
		lua_pushstring(L, "mouse_wheel");
		push_mouse_wheel_args(L, &msg->u.mouse_wheel);
		break;
	case ANT_WINDOW_MOUSE:
		lua_pushstring(L, "mouse");
		push_mouse_arg(L, &msg->u.mouse);
		break;
	case ANT_WINDOW_SIZE:
		lua_pushstring(L, "size");
		push_size_arg(L, &msg->u.size);
		break;
	case ANT_WINDOW_CHAR:
		lua_pushstring(L, "char");
		push_char_arg(L, &msg->u.unichar);
		break;
	default:
		return 0;
	}
	return 1;
}

static void
message_callback(struct ant_window_callback* cb, struct ant_window_message *msg) {
	lua_State* L = cb->messageL;
	if (!push_arg(L, msg)) {
		return;
	}
	int n = lua_gettop(L) - 1;
	lua_createtable(L, n, 1);
	lua_insert(L, 2);
	for (int i = n; i >= 1; i--)
		lua_seti(L, 2, i);
	lua_pushinteger(L, n);
	lua_setfield(L, 2, "n");
	lua_seti(L, 1, luaL_len(L, 1)+1);
}

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
	cb->surrogate = 0;
	cb->message = message_callback;
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

	if (0 != window_init(cb)) {
		return luaL_error(L, "window init failed");
	}
	return 0;
}

static int
lmainloop(lua_State *L) {
	struct ant_window_callback* cb = (struct ant_window_callback*)lua_touserdata(L, 1);
	int update = lua_toboolean(L, 2);
	window_mainloop(cb, update);
	return 0;
}

extern "C" int
luaopen_window(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", linit },
		{ "mainloop", lmainloop },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

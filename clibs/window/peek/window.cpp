#include <stdio.h>
#include <lua.hpp>
#include <stdint.h>
#include "../window.h"
#include "../virtual_keys.h"
#ifdef _WIN32
#include <windows.h>
#include <WinNT.h>
#endif //_WIN32

extern "C" {
#include <lua-seri.h>
}

struct callback_context {
	lua_State *callback;
	int surrogate;
};

static void
push_update_args(lua_State *L, struct ant_window_update *update) {
}

static void
push_init_args(lua_State *L, struct ant_window_init *init) {
	lua_pushlightuserdata(L, init->window);
	lua_pushlightuserdata(L, init->context);
	lua_pushinteger(L, init->w);
	lua_pushinteger(L, init->h);
}

static void
push_exit_args(lua_State *L, struct ant_window_exit *exit) {
}

static void
push_touch_args(lua_State *L, struct ant_window_touch *touch) {
    seri_unpackptr(L, touch->data);
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
	case ANT_WINDOW_UPDATE:
		lua_pushstring(L, "update");
		push_update_args(L, &msg->u.update);
		break;
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
		lua_pushstring(L, "touch");
		push_touch_args(L, &msg->u.touch);
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
	lua_State* L = cb->L;
	lua_settop(L, 1);
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

static int
linit(lua_State *L) {
	struct ant_window_callback* cb = (struct ant_window_callback*)lua_newuserdatauv(L, sizeof(*cb), 1);
	lua_State* dataL = lua_newthread(L);
	lua_setiuservalue(L, -2, 1);
	cb->message = message_callback;
	cb->surrogate = 0;
	cb->L = dataL;
	lua_setfield(L, LUA_REGISTRYINDEX, "ANT_WINDOW_CONTEXT");

	lua_pushvalue(L, 1);
	lua_xmove(L, dataL, 1);

	if (0 != window_init(cb)) {
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

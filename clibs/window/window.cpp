#include <lua.hpp>
#include "window.h"

static void push_message(lua_State* L) {
	int n = lua_gettop(L) - 1;
	lua_createtable(L, n, 1);
	lua_insert(L, 2);
	for (int i = n; i >= 1; i--)
		lua_seti(L, 2, i);
	lua_pushinteger(L, n);
	lua_setfield(L, 2, "n");
	lua_seti(L, 1, luaL_len(L, 1)+1);
}

void window_message_init(struct ant_window_callback* cb, void* window, void* context, int w, int h) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "init");
	lua_pushlightuserdata(L, window);
	lua_pushlightuserdata(L, context);
	lua_pushinteger(L, w);
	lua_pushinteger(L, h);
	push_message(L);
}

void window_message_recreate(struct ant_window_callback* cb, void* window, void* context, int w, int h) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "recreate");
	lua_pushlightuserdata(L, window);
	lua_pushlightuserdata(L, context);
	lua_pushinteger(L, w);
	lua_pushinteger(L, h);
	push_message(L);
}

void window_message_exit(struct ant_window_callback* cb) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "exit");
	push_message(L);
}

void window_message_keyboard(struct ant_window_callback* cb, int key, uint8_t state, uint8_t press) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "keyboard");
	lua_pushinteger(L, key);
	lua_pushinteger(L, press);
	lua_pushinteger(L, state);
	push_message(L);
}

void window_message_mouse_wheel(struct ant_window_callback* cb, int x, int y, float delta) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "mouse_wheel");
	lua_pushinteger(L, x);
	lua_pushinteger(L, y);
	lua_pushnumber(L, delta);
	push_message(L);
}

void window_message_mouse(struct ant_window_callback* cb, int x, int y, uint8_t type, uint8_t state) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "mouse");
	lua_pushinteger(L, x);
	lua_pushinteger(L, y);
	lua_pushinteger(L, type);
	lua_pushinteger(L, state);
	push_message(L);
}

void window_message_size(struct ant_window_callback* cb, int x, int y, uint8_t type) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "size");
	lua_pushinteger(L, x);
	lua_pushinteger(L, y);
	lua_pushinteger(L, type);
	push_message(L);
}

void window_message_gesture(struct ant_window_callback* cb, struct ant_gesture_tap const& gesture) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "gesture");
	lua_pushstring(L, "tap");
	lua_createtable(L, 0, 2);
	lua_pushnumber(L, static_cast<lua_Number>(gesture.x));
	lua_setfield(L, -2, "x");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.y));
	lua_setfield(L, -2, "y");
	push_message(L);
}

void window_message_gesture(struct ant_window_callback* cb, struct ant_gesture_pinch const& gesture) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "gesture");
	lua_pushstring(L, "pinch");
	lua_createtable(L, 0, 4);
	switch (gesture.state) {
	case 0: lua_pushstring(L, "began"); break;
	case 1: lua_pushstring(L, "changed"); break;
	default: case 2: lua_pushstring(L, "ended"); break;
	}
	lua_setfield(L, -2, "state");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.x));
	lua_setfield(L, -2, "x");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.y));
	lua_setfield(L, -2, "y");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.velocity));
	lua_setfield(L, -2, "velocity");
	push_message(L);
}

void window_message_gesture(struct ant_window_callback* cb, struct ant_gesture_longpress const& gesture) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "gesture");
	lua_pushstring(L, "long_press");
	lua_createtable(L, 0, 2);
	lua_pushnumber(L, static_cast<lua_Number>(gesture.x));
	lua_setfield(L, -2, "x");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.y));
	lua_setfield(L, -2, "y");
	push_message(L);
}

void window_message_gesture(struct ant_window_callback* cb, struct ant_gesture_pan const& gesture) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "gesture");
	lua_pushstring(L, "pan");
	lua_createtable(L, 0, 6);
	lua_pushnumber(L, static_cast<lua_Number>(gesture.x));
	lua_setfield(L, -2, "x");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.y));
	lua_setfield(L, -2, "y");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.dx));
	lua_setfield(L, -2, "dx");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.dy));
	lua_setfield(L, -2, "dy");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.vx));
	lua_setfield(L, -2, "vx");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.vy));
	lua_setfield(L, -2, "vy");
	push_message(L);
}

void window_message_gesture(struct ant_window_callback* cb, struct ant_gesture const& gesture) {
	switch (gesture.type) {
	case GESTURE_TAP:
		window_message_gesture(cb, gesture.tap);
		break;
	case GESTURE_PINCH:
		window_message_gesture(cb, gesture.pinch);
		break;
	case GESTURE_LONGPRESS:
		window_message_gesture(cb, gesture.longpress);
		break;
	case GESTURE_PAN:
		window_message_gesture(cb, gesture.pan);
		break;
	default:
		break;
	}
}

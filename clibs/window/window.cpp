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

void window_message_size(struct ant_window_callback* cb, int x, int y) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "size");
	lua_pushinteger(L, x);
	lua_pushinteger(L, y);
	push_message(L);
}

namespace ant::window {
void input_message(struct ant_window_callback* cb, struct msg_keyboard const& keyboard) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "keyboard");
	lua_pushinteger(L, keyboard.key);
	lua_pushinteger(L, keyboard.press);
	lua_pushinteger(L, keyboard.state);
	push_message(L);
}

void input_message(struct ant_window_callback* cb, struct msg_mouse const& mouse) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "mouse");
	lua_pushinteger(L, mouse.x);
	lua_pushinteger(L, mouse.y);
	lua_pushinteger(L, mouse.type);
	lua_pushinteger(L, mouse.state);
	push_message(L);
}

void input_message(struct ant_window_callback* cb, struct msg_mousewheel const& mousewheel) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "mousewheel");
	lua_pushinteger(L, mousewheel.x);
	lua_pushinteger(L, mousewheel.y);
	lua_pushnumber(L, mousewheel.delta);
	push_message(L);
}

void input_message(struct ant_window_callback* cb, struct msg_touch const& touch) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "touch");
	lua_pushinteger(L, (lua_Integer)touch.id);
	lua_pushinteger(L, (lua_Integer)touch.type);
	lua_pushnumber(L, static_cast<lua_Number>(touch.x));
	lua_pushnumber(L, static_cast<lua_Number>(touch.y));
	push_message(L);
}

void input_message(struct ant_window_callback* cb, struct msg_gesture_tap const& gesture) {
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

void input_message(struct ant_window_callback* cb, struct msg_gesture_pinch const& gesture) {
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

void input_message(struct ant_window_callback* cb, struct msg_gesture_longpress const& gesture) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "gesture");
	lua_pushstring(L, "longpress");
	lua_createtable(L, 0, 2);
	lua_pushnumber(L, static_cast<lua_Number>(gesture.x));
	lua_setfield(L, -2, "x");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.y));
	lua_setfield(L, -2, "y");
	push_message(L);
}

void input_message(struct ant_window_callback* cb, struct msg_gesture_pan const& gesture) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "gesture");
	lua_pushstring(L, "pan");
	lua_createtable(L, 0, 5);
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
	lua_pushnumber(L, static_cast<lua_Number>(gesture.dx));
	lua_setfield(L, -2, "dx");
	lua_pushnumber(L, static_cast<lua_Number>(gesture.dy));
	lua_setfield(L, -2, "dy");
	push_message(L);
}

void input_message(struct ant_window_callback* cb, struct msg_suspend const& suspend) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "suspend");
	switch (suspend.what) {
	case suspend::will_suspend: lua_pushstring(L, "will_suspend"); break;
	case suspend::did_suspend: lua_pushstring(L, "did_suspend"); break;
	case suspend::will_resume: lua_pushstring(L, "will_resume"); break;
	case suspend::did_resume: lua_pushstring(L, "did_resume"); break;
	}
	push_message(L);
}

void input_message(struct ant_window_callback* cb, struct msg const& m) {
	switch (m.type) {
	case msg_type::keyboard:
		input_message(cb, m.keyboard);
		break;
	case msg_type::mouse:
		input_message(cb, m.mouse);
		break;
	case msg_type::mousewheel:
		input_message(cb, m.mousewheel);
		break;
	case msg_type::touch:
		input_message(cb, m.touch);
		break;
	case msg_type::gesture_tap:
		input_message(cb, m.tap);
		break;
	case msg_type::gesture_pinch:
		input_message(cb, m.pinch);
		break;
	case msg_type::gesture_longpress:
		input_message(cb, m.longpress);
		break;
	case msg_type::suspend:
		input_message(cb, m.suspend);
		break;
	default:
		break;
	}
}
}

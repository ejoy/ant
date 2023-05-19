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

void window_message_char(struct ant_window_callback* cb, int code) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	lua_pushstring(L, "char");
	lua_pushinteger(L, code);
	push_message(L);
}

void window_message(struct ant_window_callback* cb, std::function<void(struct lua_State*)> func) {
	lua_State* L = cb->messageL;
	lua_settop(L, 1);
	func(L);
	push_message(L);
}

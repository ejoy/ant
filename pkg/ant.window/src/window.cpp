#include <lua.hpp>
#include "window.h"
#include <utility>
#include <bee/nonstd/unreachable.h>

#if defined(_WIN32)

#include <windows.h>

static uint64_t get_timestamp() {
	return GetTickCount64();
}

#else

#include <time.h>

static uint64_t get_timestamp() {
    struct timespec ti;
    clock_gettime(CLOCK_MONOTONIC, &ti);
    return (uint64_t)ti.tv_sec * 1000 + ti.tv_nsec / 1000000;
}

#endif

static void push_message_arg(lua_State* L, bool v) {
	lua_pushboolean(L, v);
}

static void push_message_arg(lua_State* L, const char* v) {
	lua_pushstring(L, v);
}

static void push_message_arg(lua_State* L, int v) {
	lua_pushinteger(L, static_cast<lua_Integer>(v));
}

static void push_message_arg(lua_State* L, uint8_t v) {
	lua_pushinteger(L, static_cast<lua_Integer>(v));
}

static void push_message_arg(lua_State* L, uintptr_t v) {
	lua_pushinteger(L, static_cast<lua_Integer>(v));
}

static void push_message_arg(lua_State* L, float v) {
	lua_pushnumber(L, static_cast<lua_Number>(v));
}

static void push_message_arg(lua_State* L, void* v) {
	if (v) {
		lua_pushlightuserdata(L, v);
	}
	else {
		lua_pushnil(L);
	}
}

static void push_message_arg(lua_State* L, ant::window::touch_state v) {
	switch (v) {
	case ant::window::touch_state::began: lua_pushstring(L, "began"); break;
	case ant::window::touch_state::moved: lua_pushstring(L, "moved"); break;
	case ant::window::touch_state::ended: lua_pushstring(L, "ended"); break;
	case ant::window::touch_state::cancelled: lua_pushstring(L, "cancelled"); break;
	default: std::unreachable();
	}
}

static void push_message_arg(lua_State* L, ant::window::gesture_state v) {
	switch (v) {
	case ant::window::gesture_state::began:
		lua_pushstring(L, "began");
		break;
	case ant::window::gesture_state::changed:
		lua_pushstring(L, "changed");
		break;
	case ant::window::gesture_state::ended:
		lua_pushstring(L, "ended");
		break;
	case ant::window::gesture_state::unknown:
		lua_pushstring(L, "ended");
		break;
	default:
		std::unreachable();
	}
}

static void push_message_arg(lua_State* L, ant::window::swipe_direction v) {
	switch (v) {
	case ant::window::swipe_direction::left:
		lua_pushstring(L, "left");
		break;
	case ant::window::swipe_direction::right:
		lua_pushstring(L, "right");
		break;
	case ant::window::swipe_direction::up:
		lua_pushstring(L, "up");
		break;
	case ant::window::swipe_direction::down:
		lua_pushstring(L, "down");
		break;
	default:
		std::unreachable();
	}
}

static void push_message_arg(lua_State* L, ant::window::suspend v) {
	switch (v) {
	case ant::window::suspend::will_suspend: lua_pushstring(L, "will_suspend"); break;
	case ant::window::suspend::did_suspend: lua_pushstring(L, "did_suspend"); break;
	case ant::window::suspend::will_resume: lua_pushstring(L, "will_resume"); break;
	case ant::window::suspend::did_resume: lua_pushstring(L, "did_resume"); break;
	default: std::unreachable();
	}
}

static void push_message_arg(lua_State* L, ant::window::mouse_button v) {
	switch (v) {
	case ant::window::mouse_button::left: lua_pushstring(L, "LEFT"); break;
	case ant::window::mouse_button::middle: lua_pushstring(L, "MIDDLE"); break;
	case ant::window::mouse_button::right: lua_pushstring(L, "RIGHT"); break;
	default: std::unreachable();
	}
}

static void push_message_arg(lua_State* L, ant::window::mouse_buttons v) {
	lua_newtable(L);
	using namespace ant::window;
	if ((v & mouse_buttons::left) != mouse_buttons::none) {
		lua_pushboolean(L, 1);
		lua_setfield(L, -2, "LEFT");
	}
	if ((v & mouse_buttons::middle) != mouse_buttons::none) {
		lua_pushboolean(L, 1);
		lua_setfield(L, -2, "MIDDLE");
	}
	if ((v & mouse_buttons::right) != mouse_buttons::none) {
		lua_pushboolean(L, 1);
		lua_setfield(L, -2, "RIGHT");
	}
}

static void push_message_arg(lua_State* L, ant::window::mouse_state v) {
	switch (v) {
	case ant::window::mouse_state::up: lua_pushstring(L, "UP"); break;
	case ant::window::mouse_state::down: lua_pushstring(L, "DOWN"); break;
	default: std::unreachable();
	}
}

static void push_message_arg(lua_State* L, ant::window::inputchar_type v) {
	switch (v) {
	case ant::window::inputchar_type::native: lua_pushstring(L, "native"); break;
	case ant::window::inputchar_type::utf16: lua_pushstring(L, "utf16"); break;
	default: std::unreachable();
	}
}

static void push_message_arg(lua_State* L, ant::window::keyboard_state v) {
	lua_newtable(L);
	if (v.kb_ctrl) {
		lua_pushboolean(L, 1);
		lua_setfield(L, -2, "CTRL");
	}
	if (v.kb_shift) {
		lua_pushboolean(L, 1);
		lua_setfield(L, -2, "SHIFT");
	}
	if (v.kb_alt) {
		lua_pushboolean(L, 1);
		lua_setfield(L, -2, "ALT");
	}
	if (v.kb_sys) {
		lua_pushboolean(L, 1);
		lua_setfield(L, -2, "SYS");
	}
	if (v.kb_capslock) {
		lua_pushboolean(L, 1);
		lua_setfield(L, -2, "CAPSLOCK");
	}
}

static void push_message_arg(lua_State* L, std::vector<std::string> const& strs) {
	lua_createtable(L, (int)strs.size(), 0);
	lua_Integer n = 0;
	for (auto const& str: strs) {
		lua_pushlstring(L, str.data(), str.size());
		lua_seti(L, -2, ++n);
	}
}

template <typename K, typename V, typename... Args>
static void push_message_args(lua_State*L, K&& k, V&& v, Args&&... args) {
	push_message_arg(L, std::forward<K>(k));
	push_message_arg(L, std::forward<V>(v));
	lua_rawset(L, -3);
	if constexpr (sizeof...(args) > 0) {
		push_message_args(L, std::forward<Args>(args)...);
	}
}

static void DefaultMessageFetch(lua_State* L) {
	lua_seti(L, 1, luaL_len(L, 1)+1);
	lua_settop(L, 1);
}

static void (*MessageFetch)(lua_State*) = DefaultMessageFetch;
void window_message_set_fetch_func(void (*func)(lua_State*)) {
	MessageFetch = func;
}

template <typename... Args>
static void push_message(lua_State* L, Args&&... args) {
	static_assert(sizeof...(args) % 2 == 0);
	lua_createtable(L, 0, 1 + sizeof...(args) / 2);
	lua_pushinteger(L, get_timestamp());
	lua_setfield(L, -2, "timestamp");
	push_message_args(L, std::forward<Args>(args)...);
	MessageFetch(L);
}

void window_message_init(lua_State* L, void* window, void* nwh, void* ndt, void *context, int w, int h) {
	push_message(L,
		"type", "init",
		"window", window,
		"nwh", nwh,
		"ndt", ndt,
		"context", context,
		"w", w,
		"h", h
	);
}

void window_message_recreate(lua_State* L, void* window, void* nwh, void* ndt, void *context, int w, int h) {
	push_message(L,
		"type", "recreate",
		"window", window,
		"nwh", nwh,
		"ndt", ndt,
		"context", context,
		"w", w,
		"h", h
	);
}

void window_message_exit(lua_State* L) {
	push_message(L,
		"type", "exit"
	);
}

void window_message_size(lua_State* L, int x, int y) {
	push_message(L,
		"type", "size",
		"w", x,
		"h", y
	);
}

void window_message_dropfiles(lua_State* L, std::vector<std::string> const& files) {
	push_message(L,
		"type", "dropfiles",
		"files", files
	);
}

namespace ant::window {
void input_message(lua_State* L, struct msg_keyboard const& keyboard) {
	push_message(L,
		"type", "keyboard",
		"key", keyboard.key,
		"press", keyboard.press,
		"state", keyboard.state
	);
}

void input_message(lua_State* L, struct msg_mouseclick const& mouseclick) {
	push_message(L,
		"type", "mouseclick",
		"what", mouseclick.what,
		"x", mouseclick.x,
		"y", mouseclick.y,
		"state", mouseclick.state
	);
}

void input_message(lua_State* L, struct msg_mousemove const& mousemove) {
	push_message(L,
		"type", "mousemove",
		"what", mousemove.what,
		"x", mousemove.x,
		"y", mousemove.y
	);
}

void input_message(lua_State* L, struct msg_mousewheel const& mousewheel) {
	push_message(L,
		"type", "mousewheel",
		"x", mousewheel.x,
		"y", mousewheel.y,
		"delta", mousewheel.delta
	);
}

void input_message(lua_State* L, struct msg_inputchar const& inputchar) {
	push_message(L,
		"type", "inputchar",
		"what", inputchar.what,
		"code", inputchar.code
	);
}

void input_message(lua_State* L, struct msg_focus const& focus) {
	push_message(L,
		"type", "focus",
		"focused", focus.focused
	);
}

void input_message(lua_State* L, struct msg_touch const& touch) {
	push_message(L,
		"type", "touch",
		"x", touch.x,
		"y", touch.y,
		"id", touch.id,
		"state", touch.state
	);
}

void input_message(lua_State* L, struct msg_gesture_tap const& gesture) {
	push_message(L,
		"type", "gesture",
		"what", "tap",
		"x", gesture.x,
		"y", gesture.y
	);
}

void input_message(lua_State* L, struct msg_gesture_pinch const& gesture) {
	push_message(L,
		"type", "gesture",
		"what", "pinch",
		"state", gesture.state,
		"x", gesture.x,
		"y", gesture.y,
		"velocity", gesture.velocity
	);
}

void input_message(lua_State* L, struct msg_gesture_longpress const& gesture) {
	push_message(L,
		"type", "gesture",
		"what", "longpress",
		"state", gesture.state,
		"x", gesture.x,
		"y", gesture.y
	);
}

void input_message(lua_State* L, struct msg_gesture_pan const& gesture) {
	push_message(L,
		"type", "gesture",
		"what", "pan",
		"state", gesture.state,
		"x", gesture.x,
		"y", gesture.y,
		"velocity_x", gesture.velocity_x,
		"velocity_y", gesture.velocity_y
	);
}

void input_message(lua_State* L, struct msg_gesture_swipe const& gesture) {
	push_message(L,
		"type", "gesture",
		"what", "swipe",
		"state", gesture.state,
		"x", gesture.x,
		"y", gesture.y,
		"direction", gesture.direction
	);
}

void input_message(lua_State* L, struct msg_suspend const& suspend) {
	push_message(L,
		"type", "suspend",
		"what", suspend.what
	);
}
}

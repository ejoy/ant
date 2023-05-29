#pragma once

#include <functional>
#include <cstdint>
#include <cstddef>

struct lua_State;

typedef enum {
	KB_CTRL,
	KB_SHIFT,
	KB_ALT,
	KB_SYS,
	KB_CAPSLOCK,
} KEYBOARD_STATE;

typedef enum {
	TOUCH_BEGAN = 1,
	TOUCH_MOVED = 2,
	TOUCH_ENDED = 3,
	TOUCH_CANCELLED = 4,
} TOUCH_TYPE;

struct ant_window_callback {
	void (*update)(struct ant_window_callback* cb);
	struct lua_State* messageL;
	struct lua_State* updateL;
};

int  window_init(struct ant_window_callback* cb);
void window_close();
bool window_peekmessage();
void window_mainloop();

void window_message_init(struct ant_window_callback* cb, void* window, void* context, int w, int h);
void window_message_recreate(struct ant_window_callback* cb, void* window, void* context, int w, int h);
void window_message_exit(struct ant_window_callback* cb);
void window_message_keyboard(struct ant_window_callback* cb, int key, uint8_t state, uint8_t press);
void window_message_mouse_wheel(struct ant_window_callback* cb, int x, int y, float delta);
void window_message_mouse(struct ant_window_callback* cb, int x, int y, uint8_t type, uint8_t state);
void window_message_size(struct ant_window_callback* cb, int x, int y, uint8_t type);
void window_message_char(struct ant_window_callback* cb, int code);
void window_message(struct ant_window_callback* cb, std::function<void(struct lua_State*)> func);

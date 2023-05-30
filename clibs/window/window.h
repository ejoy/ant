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

typedef enum {
	GESTURE_TAP = 0,
	GESTURE_PINCH = 1,
	GESTURE_LONGPRESS = 2,
	GESTURE_PAN = 3,
} GESTURE_TYPE;

struct ant_gesture_tap {
	float x;
	float y;
};
struct ant_gesture_pinch {
	int state;
	float x;
	float y;
	float velocity;
};
struct ant_gesture_longpress {
	float x;
	float y;
};
struct ant_gesture_pan {
	float x;
	float y;
	float dx;
	float dy;
	float vx;
	float vy;
};
struct ant_gesture {
	GESTURE_TYPE type;
	union {
		struct ant_gesture_tap tap;
		struct ant_gesture_pinch pinch;
		struct ant_gesture_longpress longpress;
		struct ant_gesture_pan pan;
	};
};

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
void window_message_gesture(struct ant_window_callback* cb, struct ant_gesture_tap const& gesture);
void window_message_gesture(struct ant_window_callback* cb, struct ant_gesture_pinch const& gesture);
void window_message_gesture(struct ant_window_callback* cb, struct ant_gesture_longpress const& gesture);
void window_message_gesture(struct ant_window_callback* cb, struct ant_gesture_pan const& gesture);
void window_message_gesture(struct ant_window_callback* cb, struct ant_gesture const& gesture);
void window_message(struct ant_window_callback* cb, std::function<void(struct lua_State*)> func);

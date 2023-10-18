#pragma once

#include <cstdint>
#include <cstddef>

struct lua_State;

struct ant_window_callback {
	void (*update)(struct ant_window_callback* cb);
	struct lua_State* messageL;
	struct lua_State* updateL;
};

int  window_init(struct ant_window_callback* cb);
void window_close();
bool window_peekmessage();
void window_mainloop();
void window_maxfps(float fps);

void window_message_init(struct ant_window_callback* cb, void* window, void* context, int w, int h);
void window_message_recreate(struct ant_window_callback* cb, void* window, void* context, int w, int h);
void window_message_exit(struct ant_window_callback* cb);
void window_message_size(struct ant_window_callback* cb, int x, int y);


namespace ant::window {
	enum KEYBOARD_STATE : uint8_t {
		KB_CTRL,
		KB_SHIFT,
		KB_ALT,
		KB_SYS,
		KB_CAPSLOCK,
	};
	enum TOUCH_TYPE : uint8_t {
		TOUCH_BEGAN = 1,
		TOUCH_MOVED = 2,
		TOUCH_ENDED = 3,
		TOUCH_CANCELLED = 4,
	};
	enum MOUSE_TYPE : uint8_t {
		MOUSE_LEFT = 1,
		MOUSE_MIDDLE = 2,
		MOUSE_RIGHT = 3,
	};
	enum MOUSE_STATE : uint8_t {
		MOUSE_DOWN = 1,
		MOUSE_MOVE = 2,
		MOUSE_UP = 3,
	};
	inline uint8_t get_keystate(bool kb_ctrl, bool kb_shift, bool kb_alt, bool kb_sys, bool kb_capslock) {
		return 0
			| (kb_ctrl ? (uint8_t)(1 << KB_CTRL) : 0)
			| (kb_shift ? (uint8_t)(1 << KB_SHIFT) : 0)
			| (kb_alt ? (uint8_t)(1 << KB_ALT) : 0)
			| (kb_sys ? (uint8_t)(1 << KB_SYS) : 0)
			| (kb_capslock ? (uint8_t)(1 << KB_CAPSLOCK) : 0)
			;
	}
	struct msg_keyboard {
		int key;
		uint8_t state;
		uint8_t press;
	};
	struct msg_mouse {
		int x;
		int y;
		MOUSE_TYPE type;
		MOUSE_STATE state;
	};
	struct msg_mousewheel {
		int x;
		int y;
		float delta;
	};
	struct msg_touch {
		uintptr_t id;
		TOUCH_TYPE type;
		float x;
		float y;
	};
	struct msg_gesture_tap {
		float x;
		float y;
	};
	struct msg_gesture_pinch {
		int state;
		float x;
		float y;
		float velocity;
	};
	struct msg_gesture_longpress {
		int state;
		float x;
		float y;
	};
	struct msg_gesture_pan {
		int state;
		float x;
		float y;
		float dx;
		float dy;
	};
	enum class suspend {
		will_suspend,
		did_suspend,
		will_resume,
		did_resume,
	};
	struct msg_suspend {
		suspend what;
	};


	enum class msg_type {
		keyboard,
		mouse,
		mousewheel,
		touch,
		gesture_tap,
		gesture_pinch,
		gesture_longpress,
		gesture_pan,
		suspend,
	};
	struct msg {
		msg_type type;
		union {
			struct msg_keyboard keyboard;
			struct msg_mouse mouse;
			struct msg_mousewheel mousewheel;
			struct msg_touch touch;
			struct msg_gesture_tap tap;
			struct msg_gesture_pinch pinch;
			struct msg_gesture_longpress longpress;
			struct msg_gesture_pan pan;
			struct msg_suspend suspend;
		};
	};

	void input_message(struct ant_window_callback* cb, struct msg_keyboard const& keyboard);
	void input_message(struct ant_window_callback* cb, struct msg_mouse const& mouse);
	void input_message(struct ant_window_callback* cb, struct msg_mousewheel const& mousewheel);
	void input_message(struct ant_window_callback* cb, struct msg_touch const& touch);
	void input_message(struct ant_window_callback* cb, struct msg_gesture_tap const& gesture);
	void input_message(struct ant_window_callback* cb, struct msg_gesture_pinch const& gesture);
	void input_message(struct ant_window_callback* cb, struct msg_gesture_longpress const& gesture);
	void input_message(struct ant_window_callback* cb, struct msg_gesture_pan const& gesture);
	void input_message(struct ant_window_callback* cb, struct msg_suspend const& suspend);
	void input_message(struct ant_window_callback* cb, struct msg const& m);
}

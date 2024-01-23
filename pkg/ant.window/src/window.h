#pragma once

#include <cstdint>
#include <cstddef>
#include <string>
#include <string_view>
#include <vector>
#include <imgui.h>
#include "enum.h"
#include <bee/utility/zstring_view.h>

struct lua_State;

struct ant_window_callback {
	void (*update)(struct ant_window_callback* cb);
	struct lua_State* messageL;
	struct lua_State* updateL;
};

void* peekwindow_init(struct ant_window_callback* cb, const char* size);
void peekwindow_close();
bool peekwindow_peek_message();
void peekwindow_set_cursor(int cursor);
void peekwindow_set_title(bee::zstring_view title);

void loopwindow_init(struct ant_window_callback* cb);
void loopwindow_mainloop();

void window_maxfps(float fps);

void window_message_init(struct ant_window_callback* cb, void* window, void* context, int w, int h);
void window_message_recreate(struct ant_window_callback* cb, void* window, void* context, int w, int h);
void window_message_exit(struct ant_window_callback* cb);
void window_message_size(struct ant_window_callback* cb, int x, int y);
void window_message_dropfiles(struct ant_window_callback* cb, std::vector<std::string> const& files);

namespace ant::window {
	enum class swipe_direction : uint8_t {
		right = 1 << 0,
		left = 1 << 1,
		up = 1 << 2,
		down = 1 << 3,
	};
	enum class mouse_button : uint8_t {
		left,
		middle,
		right,
	};
	enum class mouse_buttons : uint8_t {
		none = 0,
		left = 1,
		middle = 2,
		right = 4,
	};
	enum class mouse_state : uint8_t {
		down,
		up,
	};
	enum class inputchar_type : uint8_t {
		native,
		utf16,
	};
	enum class touch_state : uint8_t {
		began,
		moved,
		ended,
		cancelled,
	};
	enum class gesture_state : uint8_t {
		began,
		changed,
		ended,
		unknown,
	};
	enum class suspend : uint8_t {
		will_suspend,
		did_suspend,
		will_resume,
		did_resume,
	};
	struct keyboard_state {
		uint8_t kb_ctrl: 1;
		uint8_t kb_shift: 1;
		uint8_t kb_alt: 1;
		uint8_t kb_sys: 1;
		uint8_t kb_capslock: 1;
	};
	inline keyboard_state get_keystate(bool kb_ctrl, bool kb_shift, bool kb_alt, bool kb_sys, bool kb_capslock) {
		return {
			kb_ctrl,
			kb_shift,
			kb_alt,
			kb_sys,
			kb_capslock,
		};
	}
	struct msg_keyboard {
		ImGuiKey key;
		keyboard_state state;
		uint8_t press;
	};
	struct msg_mouseclick {
		int x;
		int y;
		mouse_button what;
		mouse_state state;
	};
	struct msg_mousemove {
		int x;
		int y;
		mouse_buttons what;
	};
	struct msg_mousewheel {
		int x;
		int y;
		float delta;
	};
	struct msg_inputchar {
		inputchar_type what;
		uint16_t code;
	};
	struct msg_focus {
		bool focused;
	};
	struct msg_touch {
		uintptr_t id;
		float x;
		float y;
		touch_state state;
	};
	struct msg_gesture_tap {
		float x;
		float y;
	};
	struct msg_gesture_pinch {
		float x;
		float y;
		float velocity;
		gesture_state state;
	};
	struct msg_gesture_longpress {
		float x;
		float y;
		gesture_state state;
	};
	struct msg_gesture_pan {
		gesture_state state;
		float x;
		float y;
		float velocity_x;
		float velocity_y;
	};
	struct msg_gesture_swipe {
		float x;
		float y;
		gesture_state state;
		swipe_direction direction;
	};
	struct msg_suspend {
		suspend what;
	};

ENUM_FLAG_OPERATORS(mouse_buttons)

	enum class msg_type {
		keyboard,
		mouse,
		mousewheel,
		inputchar,
		touch,
		gesture_tap,
		gesture_pinch,
		gesture_longpress,
		gesture_pan,
		gesture_swipe,
		suspend,
	};
	struct msg {
		msg_type type;
		union {
			struct msg_keyboard keyboard;
			struct msg_mouseclick mouseclick;
			struct msg_mousemove mousemove;
			struct msg_mousewheel mousewheel;
			struct msg_inputchar inputchar;
			struct msg_focus focus;
			struct msg_touch touch;
			struct msg_gesture_tap tap;
			struct msg_gesture_pinch pinch;
			struct msg_gesture_longpress longpress;
			struct msg_gesture_pan pan;
			struct msg_gesture_swipe swipe;
			struct msg_suspend suspend;
		};
	};

	void input_message(struct ant_window_callback* cb, struct msg_keyboard const& keyboard);
	void input_message(struct ant_window_callback* cb, struct msg_mouseclick const& mouseclick);
	void input_message(struct ant_window_callback* cb, struct msg_mousemove const& mousemove);
	void input_message(struct ant_window_callback* cb, struct msg_mousewheel const& mousewheel);
	void input_message(struct ant_window_callback* cb, struct msg_inputchar const& inputchar);
	void input_message(struct ant_window_callback* cb, struct msg_focus const& focus);
	void input_message(struct ant_window_callback* cb, struct msg_touch const& touch);
	void input_message(struct ant_window_callback* cb, struct msg_gesture_tap const& gesture);
	void input_message(struct ant_window_callback* cb, struct msg_gesture_pinch const& gesture);
	void input_message(struct ant_window_callback* cb, struct msg_gesture_longpress const& gesture);
	void input_message(struct ant_window_callback* cb, struct msg_gesture_pan const& gesture);
	void input_message(struct ant_window_callback* cb, struct msg_gesture_swipe const& gesture);
	void input_message(struct ant_window_callback* cb, struct msg_suspend const& suspend);
}


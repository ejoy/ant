#ifndef ant_window_h
#define ant_window_h

#include <stdint.h>

#define ANT_WINDOW_UPDATE 0
#define ANT_WINDOW_EXIT 1
#define ANT_WINDOW_TOUCH 2
#define ANT_WINDOW_KEYBOARD 3
#define ANT_WINDOW_MOUSE_MOVE 4
#define ANT_WINDOW_MOUSE_WHEEL 5
#define ANT_WINDOW_MOUSE_CLICK 6

#define ANT_WINDOW_CALLBACK "ANT_WINDOW_CALLBACK"

struct ant_window_update {
	size_t dump;
};

struct ant_window_exit {
	size_t dump;
};

struct ant_window_touch {
	int x;
	int y;
	uint8_t what;	// 0: lbutton up ; 1: lbutton down; 2: rbutton up; 3 rbutton down
};

typedef enum {
	KB_CTRL,
	KB_ALT,
	KB_SHIFT,
	KB_SYS,
	KB_CAPSLOCK,
}KEYBOARD_STATE;

struct ant_window_keyboard {
	int key;
	uint8_t state; // ctrl, alt, shift, in low 3 bits; left or right, in low 4 bit
	uint8_t press; // 0: up ; 1: down
};

struct ant_window_mouse_wheel {
	int x;
	int y;
	float delta;
};

struct ant_window_mouse_move {
	int x;
	int y;
	uint8_t state; // lbutton, rbutton, mbutton
};

struct ant_window_mouse_click {
	int x;
	int y;
	uint8_t type;  // 0: lbutton; 1: rbutton up; 2 mbutton
	uint8_t press; // 0: up ; 1: down
};

struct ant_window_message {
	int type;
	union {
		struct ant_window_update update;
		struct ant_window_exit exit;
		struct ant_window_touch touch;
		struct ant_window_keyboard keyboard;
		struct ant_window_mouse_move mouse_move;
		struct ant_window_mouse_wheel mouse_wheel;
		struct ant_window_mouse_click mouse_click;
	} u;
};

struct ant_window_callback {
	void (*message)(void *ud, struct ant_window_message *);
	void *ud;
};

#endif

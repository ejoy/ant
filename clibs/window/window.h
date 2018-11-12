#ifndef ant_window_h
#define ant_window_h

#include <lua.h>

#define ANT_WINDOW_UPDATE 0
#define ANT_WINDOW_EXIT 1
#define ANT_WINDOW_TOUCH 2
#define ANT_WINDOW_MOVE 3

#define ANT_WINDOW_CALLBACK "ANT_WINDOW_CALLBACK"

struct ant_window_update {
	size_t dump;
};

struct ant_window_exit {
	size_t dump;
};

struct ant_window_touch {
	int what;	// 0: lbutton up ; 1: lbutton down
	int x;
	int y;
};

struct ant_window_move {
	int x;
	int y;
};

struct ant_window_message {
	int type;
	union {
		struct ant_window_update update;
		struct ant_window_exit exit;
		struct ant_window_touch touch;
		struct ant_window_move move;
	} u;
};

struct ant_window_callback {
	void (*message)(void *ud, struct ant_window_message *);
	void *ud;
};

#endif

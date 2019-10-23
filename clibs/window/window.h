#ifndef ant_window_h
#define ant_window_h

#include <stdint.h>
#include <stddef.h>
#ifdef _WIN32
#include <windows.h>
#include <WinNT.h>
#endif //_WIN32

typedef enum {
	ANT_WINDOW_UPDATE = 1,
	ANT_WINDOW_INIT,
	ANT_WINDOW_EXIT,
	ANT_WINDOW_TOUCH,
	ANT_WINDOW_KEYBOARD,
	ANT_WINDOW_MOUSE,
	ANT_WINDOW_MOUSE_WHEEL,
	ANT_WINDOW_SIZE,
	ANT_WINDOW_CHAR,
	ANT_WINDOW_DROPFILES,

	ANT_WINDOW_COUNT
} ANT_WINDOW;

#define ANT_WINDOW_CALLBACK "ANT_WINDOW_CALLBACK"

struct ant_window_update {
	size_t dump;
};

struct ant_window_init {
	void* window;
	void* context;
	int   w;
	int   h;
};

struct ant_window_exit {
	size_t dump;
};

struct ant_window_touch {
	uintptr_t id;
	int x;
	int y;
	uint8_t state; // 1: down ; 2: move ; 3: up
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

struct ant_window_mouse {
	int x;
	int y;
	uint8_t type;  // 1: lbutton; 2: rbutton; 3: mbutton
	uint8_t state; // 1: down ; 2: move ; 3: up
};

struct ant_window_size {
	int x;
	int y;
	uint8_t type;	// 0: SIZE_RESTORED 1: SIZE_MINIMIZED 2: SIZE_MAXIMIZED
};

struct ant_window_char {
	int code;
};

struct ant_window_dropfiles {
	int count;
	//WCHAR  ** paths;
	char** paths;
	int * path_counts;
};

struct ant_window_message {
	int type;
	union {
		struct ant_window_update update;
		struct ant_window_init init;
		struct ant_window_exit exit;
		struct ant_window_touch touch;
		struct ant_window_keyboard keyboard;
		struct ant_window_mouse mouse;
		struct ant_window_mouse_wheel mouse_wheel;
		struct ant_window_size size;
		struct ant_window_char unichar;
		struct ant_window_dropfiles dropfiles;
	} u;
};

struct ant_window_callback {
	void (*message)(void *ud, struct ant_window_message *);
	void *ud;
};

int  window_init(struct ant_window_callback* cb);
int  window_create(struct ant_window_callback* cb, int w, int h, const char* title, size_t sz);
void window_mainloop(struct ant_window_callback* cb, int update);
void window_ime(void* ime);
int window_set_title(void * handle, const char * title,size_t sz );

#endif

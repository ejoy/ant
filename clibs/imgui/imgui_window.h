#ifndef imgui_window_h
#define imgui_window_h

#include <lua.hpp>
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
	ANT_WINDOW_KEYBOARD,
	ANT_WINDOW_MOUSE,
	ANT_WINDOW_MOUSE_WHEEL,
	ANT_WINDOW_SIZE,
	ANT_WINDOW_DROPFILES,
	ANT_WINDOW_VIEWID,

	ANT_WINDOW_COUNT
} ANT_WINDOW;

#define WINDOW_CALLBACK "WINDOW_CALLBACK"

typedef enum {
	KB_CTRL,
	KB_ALT,
	KB_SHIFT,
	KB_SYS,
	KB_CAPSLOCK,
}KEYBOARD_STATE;

struct window_callback;

void window_register(lua_State* L, int idx);
struct window_callback* window_get_callback(lua_State* L);

void window_event_update(struct window_callback* cb);
void window_event_init(struct window_callback* cb, void* window, void* context, int w, int h);
void window_event_exit(struct window_callback* cb);
// **state** ctrl, alt, shift, in low 3 bits; left or right, in low 4 bit
// **press** 0: up ; 1: down
void window_event_keyboard(struct window_callback* cb, int key, uint8_t state, uint8_t press);
// **type**  1: lbutton; 2: rbutton; 3: mbutton
// **state** 1: down ; 2: move ; 3: up
void window_event_mouse(struct window_callback* cb, int x, int y, uint8_t type, uint8_t state);
void window_event_mouse_wheel(struct window_callback* cb, int x, int y, float delta);
// **type**  0: SIZE_RESTORED 1: SIZE_MINIMIZED 2: SIZE_MAXIMIZED
void window_event_size(struct window_callback* cb, int w, int h, int type);
void window_event_dropfiles(struct window_callback* cb, int count, char** paths, int* path_counts);
int  window_event_viewid(struct window_callback* cb);

#endif

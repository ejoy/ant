#ifndef ant_window_h
#define ant_window_h

#include <stdint.h>
#include <stddef.h>
#ifdef _WIN32
#include <windows.h>
#include <WinNT.h>
#endif //_WIN32

struct lua_State;

typedef enum {
	KB_CTRL,
	KB_SHIFT,
	KB_ALT,
	KB_SYS,
	KB_CAPSLOCK,
}KEYBOARD_STATE;

struct ant_window_callback {
	void (*update)(struct ant_window_callback* cb);
	struct lua_State* messageL;
	struct lua_State* updateL;
};

int  window_init(struct ant_window_callback* cb);
void window_close();
bool window_peekmessage();
void window_mainloop(struct ant_window_callback* cb, int update);

void window_message_init(struct ant_window_callback* cb, void* window, void* context, int w, int h);
void window_message_exit(struct ant_window_callback* cb);
void window_message_keyboard(struct ant_window_callback* cb, int key, uint8_t state, uint8_t press);
void window_message_mouse_wheel(struct ant_window_callback* cb, int x, int y, float delta);
void window_message_mouse(struct ant_window_callback* cb, int x, int y, uint8_t type, uint8_t state);
void window_message_size(struct ant_window_callback* cb, int x, int y, uint8_t type);
void window_message_char(struct ant_window_callback* cb, int code);

void window_message(struct ant_window_callback* cb, void(*func)(struct lua_State* L));

#endif

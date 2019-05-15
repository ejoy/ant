#ifndef _WINDOW_NATIVE_H_
#define _WINDOW_NATIVE_H_

#include "window.h"

#define ANT_KEYMAP_TAB 0
#define ANT_KEYMAP_LEFT 1
#define ANT_KEYMAP_RIGHT 2
#define ANT_KEYMAP_UP 3
#define ANT_KEYMAP_DOWN 4
#define ANT_KEYMAP_PAGEUP 5
#define ANT_KEYMAP_PAGEDOWN 6
#define ANT_KEYMAP_HOME 7
#define ANT_KEYMAP_END 8
#define ANT_KEYMAP_INSERT 9
#define ANT_KEYMAP_DELETE 10
#define ANT_KEYMAP_BACKSPACE 11
#define ANT_KEYMAP_SPACE 12
#define ANT_KEYMAP_ENTER 13
#define ANT_KEYMAP_ESCAPE 14
#define ANT_KEYMAP_COUNT 15

struct windowHandle {
    void* window;
    void* context;
};
struct windowSize {
    int w;
    int h;
};

int  window_init(struct ant_window_callback* cb);
int  window_create(struct ant_window_callback* cb, int w, int h, const char* title, size_t sz);
void window_mainloop(struct ant_window_callback* cb);
int window_keymap(int whatkey);

#endif

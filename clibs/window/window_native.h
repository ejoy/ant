#ifndef _WINDOW_NATIVE_H_
#define _WINDOW_NATIVE_H_

#include "window.h"

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

#endif

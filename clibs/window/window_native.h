#ifndef _WINDOW_NATIVE_H_
#define _WINDOW_NATIVE_H_

#include "window.h"

void* window_create(struct ant_window_callback* cb, int w, int h, const char* title, size_t sz);
void  window_mainloop(struct ant_window_callback* cb);

#endif

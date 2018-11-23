#ifndef _WINDOW_OSX_H_
#define _WINDOW_OSX_H_

#include <objc/objc-runtime.h>

id   window_create(int w, int h, const char* title, size_t sz);
void window_mainloop();
void window_test(id wnd);

#endif

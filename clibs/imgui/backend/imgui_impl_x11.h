#pragma once

#include <X11/keysymdef.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>

#include <cstdint>

struct WindowContext
{
    Display *dpy{NULL};
    int screen;
    Window window;
    GC gc;
    int64_t time;
    int64_t ticks_per_sec;

    WindowContext() { memset((void*)this, 0, sizeof(*this)); }
};

void ImGui_ImplX11_Init(void* ctx);
void ImGui_ImplX11_Shutdown();
void ImGui_ImplX11_NewFrame();

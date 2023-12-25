#ifndef imgui_window_h
#define imgui_window_h

#include <stdint.h>
#include <stddef.h>
#include <vector>
#include <string>

struct lua_State;
void window_register(lua_State* L, int idx);
int  window_event_viewid();

#endif

#ifndef imgui_window_h
#define imgui_window_h

#include <lua.hpp>
#include <stdint.h>
#include <stddef.h>
#include <vector>
#include <string>

typedef enum {
	ANT_WINDOW_SIZE = 1,
	ANT_WINDOW_DROPFILES,
	ANT_WINDOW_VIEWID,
	ANT_WINDOW_COUNT
} ANT_WINDOW;

void window_register(lua_State* L, int idx);
void window_event_size(int w, int h);
int  window_event_viewid();
void window_event_dropfiles(std::vector<std::string> files);

#endif

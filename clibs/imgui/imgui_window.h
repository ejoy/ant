#ifndef imgui_window_h
#define imgui_window_h

#include <lua.hpp>
#include <stdint.h>
#include <stddef.h>
#include <vector>
#include <string>
#ifdef _WIN32
#include <windows.h>
#include <WinNT.h>
#endif //_WIN32

typedef enum {
	ANT_WINDOW_SIZE = 1,
	ANT_WINDOW_DROPFILES,
	ANT_WINDOW_VIEWID,
	ANT_WINDOW_COUNT
} ANT_WINDOW;

#define WINDOW_CALLBACK "WINDOW_CALLBACK"

struct window_callback;

void window_register(lua_State* L, int idx);
struct window_callback* window_get_callback(lua_State* L);

void window_event_size(struct window_callback* cb, int w, int h);
int  window_event_viewid(struct window_callback* cb);
void window_event_dropfiles(struct window_callback* cb, std::vector<std::string> files);

#endif

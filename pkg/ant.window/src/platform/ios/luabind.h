#pragma once

struct ant_window_callback {
	void (*update)(struct ant_window_callback* cb);
	struct lua_State* messageL;
	struct lua_State* peekL;
	struct lua_State* updateL;
};
void loopwindow_init(struct ant_window_callback* cb);
void loopwindow_mainloop();

#pragma once

struct lua_State;

void msqueue_push(lua_State* L, int idx);
int  msqueue_pop(lua_State* L);

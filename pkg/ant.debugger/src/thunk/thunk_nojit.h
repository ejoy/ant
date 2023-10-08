#pragma once

#include <stdint.h>

struct thunk {
    void* data = 0;
};
struct lua_State;
intptr_t thunk_get(lua_State* L, void* key);
void thunk_set(lua_State* L, void* key, intptr_t v);
#define LUADEBUG_DISABLE_THUNK 1

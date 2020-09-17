#pragma once

#include "rlua.h"

namespace remotedebug::table {
    unsigned int array_size(const void* t);
    unsigned int hash_size(const void* t);
    int          get_kv(lua_State* L, const void* tv, unsigned int i);
    int          get_k(lua_State* L, const void* t, unsigned int i);
    int          get_k(lua_State* L, int idx, unsigned int i);
    int          get_v(lua_State* L, int idx, unsigned int i);
    int          set_v(lua_State* L, int idx, unsigned int i);
}

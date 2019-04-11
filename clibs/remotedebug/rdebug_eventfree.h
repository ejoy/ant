#pragma once

#include <lua.hpp>

namespace remotedebug::eventfree {
    typedef void (*notify)(void* ud, void* ptr);
    void create(lua_State* L, notify notify, void* ud);
    void destroy(lua_State* L);
}

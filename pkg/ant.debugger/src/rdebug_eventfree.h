#pragma once

struct lua_State;

namespace luadebug::eventfree {
    typedef void (*notify)(void* ud, void* ptr);
    void* create(lua_State* L, notify cb, void* ud);
    void destroy(lua_State* L, void* handle);
}

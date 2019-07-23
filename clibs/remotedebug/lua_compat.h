#pragma once

namespace lua {

#if LUA_VERSION_NUM >= 503
#define LUACOMPAT_DEF(name) template <typename ... Args> \
    int name(lua_State* L, Args ... args) { return lua_##name(L,args...); }
#else
#define LUACOMPAT_DEF(name) template <typename ... Args> \
    int name(lua_State* L, Args ... args) { lua_##name(L,args...); return lua_type(L,-1); }
#endif

    LUACOMPAT_DEF(rawgeti)
    LUACOMPAT_DEF(rawgetp)
    LUACOMPAT_DEF(getglobal)
    LUACOMPAT_DEF(getfield)
    LUACOMPAT_DEF(getuservalue)
    
}

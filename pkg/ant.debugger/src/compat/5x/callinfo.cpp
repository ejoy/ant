#include <lstate.h>

#include "compat/internal.h"

#if LUA_VERSION_NUM >= 504
#    define LUA_STKID(s) s.p
#else
#    define LUA_STKID(s) s
#    define s2v(o) (o)
#endif

CallInfo* lua_getcallinfo(lua_State* L) {
    return L->ci;
}

inline Proto* func2proto(StkId func) {
#if LUA_VERSION_NUM >= 502
    if (!ttisLclosure(s2v(func))) {
        return 0;
    }
    return clLvalue(s2v(func))->p;
#else
    if (clvalue(func)->c.isC) {
        return 0;
    }
    return clvalue(func)->l.p;
#endif
}

Proto* lua_ci2proto(CallInfo* ci) {
    StkId func = LUA_STKID(ci->func);
    return func2proto(func);
}

CallInfo* lua_debug2ci(lua_State* L, const lua_Debug* ar) {
#if LUA_VERSION_NUM >= 502
    return ar->i_ci;
#else
    return L->base_ci + ar->i_ci;
#endif
}

Proto* lua_getproto(lua_State* L, int idx) {
    auto func = LUA_STKID(L->top) + idx;
    return func2proto(func);
}

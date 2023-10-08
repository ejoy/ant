
#include <lstate.h>

#include "compat/internal.h"

int lua_stacklevel(lua_State* L) {
    int level = 0;
#if LUA_VERSION_NUM >= 502
    for (CallInfo* ci = L->ci; ci != &L->base_ci; ci = ci->previous) {
        level++;
    }
#else
    for (CallInfo* ci = L->ci; ci > L->base_ci; ci--) {
        level++;
        if (f_isLua(ci)) level += ci->tailcalls;
    }
#endif
    return level;
}

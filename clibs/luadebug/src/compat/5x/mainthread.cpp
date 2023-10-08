#include <lstate.h>

#include "compat/internal.h"

lua_State* lua_getmainthread(lua_State* L) {
    return L->l_G->mainthread;
}

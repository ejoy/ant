#include <lj_obj.h>

#include "compat/internal.h"

lua_State* lua_getmainthread(lua_State* L) {
    return mainthread(G(L));
}

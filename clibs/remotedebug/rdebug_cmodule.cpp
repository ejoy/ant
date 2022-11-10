#define RLUA_REPLACE
#include "rdebug_cmodule.h"
#include <bee/lua/binding.h>

extern "C" int luaopen_remotedebug_hookmgr(rlua_State* L);
extern "C" int luaopen_remotedebug_stdio(rlua_State* L);
extern "C" int luaopen_remotedebug_utility(rlua_State* L);
extern "C" int luaopen_remotedebug_visitor(rlua_State* L);
extern "C" int luaopen_bee_socket(rlua_State* L);
extern "C" int luaopen_bee_thread(rlua_State* L);
extern "C" int luaopen_bee_filesystem(rlua_State* L);
#if defined(_WIN32)
extern "C" int luaopen_bee_unicode(rlua_State* L);
#endif

static rluaL_Reg cmodule[] = {
    {"remotedebug.hookmgr", luaopen_remotedebug_hookmgr},
    {"remotedebug.stdio", luaopen_remotedebug_stdio},
    {"remotedebug.utility", luaopen_remotedebug_utility},
    {"remotedebug.visitor", luaopen_remotedebug_visitor},
    {"bee.socket", luaopen_bee_socket},
    {"bee.thread", luaopen_bee_thread},
    {"bee.filesystem", luaopen_bee_filesystem},
#if defined(_WIN32)
    {"bee.unicode", luaopen_bee_unicode},
#endif
    {NULL, NULL},
};

namespace remotedebug {
    static void require_cmodule() {
        for (const rluaL_Reg* l = cmodule; l->name != NULL; l++) {
            ::bee::lua::register_module(l->name, l->func);
        }
    }
    static ::bee::lua::callfunc _init(require_cmodule);
    int require_all(rlua_State* L) {
        ::bee::lua::preload_module(L);
        return 0;
    }
}

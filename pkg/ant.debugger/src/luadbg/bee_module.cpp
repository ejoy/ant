// clang-format off
#if defined _WIN32
#    include <winsock2.h>
#endif

#include "luadbg/inc/luadbg.hpp"
#include "luadbg/bee_module.h"

#include <bee/lua/file.h>
#include <bee/lua/module.h>

extern "C" int luaopen_luadebug_hookmgr(luadbg_State* L);
extern "C" int luaopen_luadebug_stdio(luadbg_State* L);
extern "C" int luaopen_luadebug_utility(luadbg_State* L);
extern "C" int luaopen_luadebug_visitor(luadbg_State* L);
extern "C" int luaopen_bee_socket(luadbg_State* L);
extern "C" int luaopen_bee_thread(luadbg_State* L);
extern "C" int luaopen_bee_filesystem(luadbg_State* L);
#if defined(_WIN32)
extern "C" int luaopen_bee_windows(luadbg_State* L);
#endif

static luadbgL_Reg cmodule[] = {
    { "luadebug.hookmgr", luaopen_luadebug_hookmgr },
    { "luadebug.stdio", luaopen_luadebug_stdio },
    { "luadebug.utility", luaopen_luadebug_utility },
    { "luadebug.visitor", luaopen_luadebug_visitor },
    { "bee.socket", luaopen_bee_socket },
    { "bee.thread", luaopen_bee_thread },
    { "bee.filesystem", luaopen_bee_filesystem },
#if defined(_WIN32)
    { "bee.windows", luaopen_bee_windows },
#endif
    { NULL, NULL },
};

namespace luadebug {
    static void require_cmodule() {
        for (const luadbgL_Reg* l = cmodule; l->name != NULL; l++) {
            ::bee::lua::register_module(l->name, l->func);
        }
    }
    static ::bee::lua::callfunc _init(require_cmodule);
    int require_all(luadbg_State* L) {
        ::bee::lua::preload_module(L);
        return 0;
    }
}

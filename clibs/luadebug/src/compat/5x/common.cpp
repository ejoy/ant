#include "compat/internal.h"
#include "compat/lua.h"

const void* lua_tocfunction_pointer(lua_State* L, int idx) {
    return (const void*)lua_tocfunction(L, idx);
}
#if LUA_VERSION_NUM == 501
#    include <lobject.h>
#    include <lstate.h>
namespace lua {
#    define api_incr_top(L)                    \
        {                                      \
            api_check(L, L->top < L->ci->top); \
            L->top++;                          \
        }

    const char* lua_getlocal(lua_State* L, const lua_Debug* ar, int n) {
        if (n < 0) {
            auto ci    = lua_debug2ci(L, ar);
            auto proto = lua_ci2proto(ci);
            if (!proto) {
                return nullptr;
            }

            n            = -n;
            auto nparams = proto->numparams;
            if (n >= ci->base - ci->func - nparams) {
                return nullptr;  // no such vararg
            }
            else {
                auto o = ci->func + nparams + n;
                setobj2s(L, L->top, o);
                api_incr_top(L);
                return "(*vararg)";
            }
            return nullptr;
        }
        return ::lua_getlocal(L, ar, n);
    }
}
#endif

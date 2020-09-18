#include "lua.h"

#if LUA_VERSION_NUM >= 504
#define LUA_CALLHOOK(L,event, type) luaD_hook(L, event, type, 0, 0)
#elif LUA_VERSION_NUM >= 502
#define LUA_CALLHOOK(L,event, type) luaD_hook(L, event, type)
#elif LUA_VERSION_NUM >= 501
#define LUA_CALLHOOK(L,event, type) luaD_callhook(L, event, type)
#else
#error unknown lua version
#endif

#if LUA_VERSION_NUM >= 504
#define LUA_S2V(s) s2v(s)
#else
#define LUA_S2V(s) (s)
#endif

#define luai_threadevent(L, from, type)         \
    if (L && (L->hookmask & LUA_MASKTHREAD)) {  \
        setpvalue(LUA_S2V(L->top), from);       \
        L->top++;                               \
        LUA_CALLHOOK(L, LUA_HOOKTHREAD, type);  \
        L->top--;                               \
    }

#define luai_threadcall(L, from) luai_threadevent(L, from, 0)
#define luai_threadret(L, to) luai_threadevent(L, to, 1)

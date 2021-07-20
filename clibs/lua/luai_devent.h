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
    if (L && (L->l_G->mainthread->hookmask & LUA_MASKTHREAD)) {  \
        setpvalue(LUA_S2V(L->top), from);       \
        L->top++;                               \
        LUA_CALLHOOK(L, LUA_HOOKTHREAD, type);  \
        L->top--;                               \
    }

#define luai_threadcall(L, from) luai_threadevent(L, from, 0)
#define luai_threadret(L, to) luai_threadevent(L, to, 1)

#define LUA_ERREVENT_PANIC 0x10

#if LUA_VERSION_NUM >= 504
#define luai_errevent_(L, errcode) luaD_hook(L, LUA_HOOKEXCEPTION, cast_int(L->top - L->stack), 0, errcode)
#else
#define luai_errevent_(L, errcode) LUA_CALLHOOK(L, LUA_HOOKEXCEPTION, errcode)
#endif

#define luai_errevent(L, errcode)           \
    if (L->hookmask & LUA_MASKEXCEPTION) {  \
        switch (errcode) {                  \
        case LUA_ERRRUN:                    \
        case LUA_ERRSYNTAX:                 \
        case LUA_ERRMEM:                    \
        case LUA_ERRERR: {                  \
            int code = errcode;             \
            if (!L->errorJmp) {             \
                code |= LUA_ERREVENT_PANIC; \
            }                               \
            luai_errevent_(L, code);        \
            break;                          \
        }}                                  \
    }

#include <lua.hpp>
#include <lstate.h>
#include <assert.h>
#include <stdint.h>
#include <new>
#include <memory>
#include "rdebug_eventfree.h"
#include "rdebug_timer.h"

#if LUA_VERSION_NUM < 504
#define s2v(o) (o)
#endif

static int HOOK_MGR = 0;
static int HOOK_CALLBACK = 0;

extern "C" {
lua_State* get_host(lua_State *L);
void set_host(lua_State* L, lua_State* hL);
lua_State* getthread(lua_State *L);
int copyvalue(lua_State *cL, lua_State *hL);
}

#define BPMAP_SIZE (1 << 16)

#include "thunk.h"

#define LOG(...) do { \
    FILE* f = fopen("dbg.log", "a"); \
    fprintf(f, __VA_ARGS__); \
    fclose(f); \
} while(0)

template <class T>
static T* checklightudata(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TLIGHTUSERDATA);
    return (T*)lua_touserdata(L, idx);
}

static Proto* ci2proto(CallInfo* ci) {
    StkId func = ci->func;
    if (!ttisLclosure(s2v(func))) {
        return 0;
    }
    return clLvalue(s2v(func))->p;
}

struct hookmgr {
    enum class BP : uint8_t {
        None = 0,
        Break,
        Ignore,
    };

    // 
    // break
    //
    BP     break_map[BPMAP_SIZE] = { BP::None };
    Proto* break_proto[BPMAP_SIZE] = { 0 };
    int    break_mask = 0;

    size_t break_hash(Proto* p) {
        return uintptr_t(p) % BPMAP_SIZE;
    }
    void break_add(lua_State* hL, Proto* p) {
        size_t key = break_hash(p);
        if (break_map[key] == BP::None) {
            break_map[key] = BP::Break;
            break_proto[key] = p;
        }
        else if (break_proto[key] == p) {
            break_map[key] = BP::Break;
        }
    }
    void break_del(lua_State* hL, Proto* p) {
        size_t key = break_hash(p);
        if (break_map[key] != BP::Ignore) {
            break_map[key] = BP::Ignore;
            break_proto[key] = p;
        }
    }
    void break_freeobj(Proto* p) {
        size_t key = break_hash(p);
        if (break_proto[key] == p) {
            break_map[key] = BP::None;
            break_proto[key] = 0;
        }
    }
    void break_open(lua_State* hL, lua_State* cL) {
        break_update(hL, hL->ci, LUA_HOOKCALL);
    }
    void break_close(lua_State* hL) {
        break_hookmask(hL, 0);
    }
    void break_closeline(lua_State* hL) {
        break_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
    }
    bool break_has(lua_State* hL, Proto* p, int event) {
        if (!p) {
            return false;
        }
        size_t key = break_hash(p);
        switch (break_map[key]) {
        case BP::None: {
            if (lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
                lua_pop(cL, 1);
                return false;
            }
            set_host(cL, hL);
            lua_pushstring(cL, "newproto");
            lua_pushlightuserdata(cL, p);
            lua_pushinteger(cL, event != LUA_HOOKRET? 0: 1);
            if (lua_pcall(cL, 3, 1, 0) != LUA_OK) {
                lua_pop(cL, 1);
                return false;
            }
            if (!lua_toboolean(cL, -1)) {
                break_del(hL, p);
                return false;
            }
            break_add(hL, p);
            return true;
        }
        case BP::Break:
            return true;
        default:
        case BP::Ignore:
            return break_proto[key] != p;
        }
    }
    void break_update(lua_State* hL, CallInfo* ci, int event) {
        if (break_has(hL, ci2proto(ci), event)) {
            break_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
        }
        else {
            break_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
        }
    }
    void break_hook_call(lua_State* hL, lua_Debug* ar) {
        break_update(hL, ar->i_ci, ar->event);
    }
    void break_hook_return(lua_State* hL, lua_Debug* ar) {
        break_update(hL, ar->i_ci->previous, ar->event);
    }
    void break_hookmask(lua_State* hL, int mask) {
        if (break_mask != mask) {
            break_mask = mask;
            updatehookmask(hL);
        }
    }

    // 
    // step
    //
    lua_State* stepL = 0;
    int step_current_level = 0;
    int step_target_level = 0;
    int step_mask = 0;
    
    // TODO
    static int stacklevel(lua_State* L) {
        lua_Debug ar;
        int n;
        for (n = 0; lua_getstack(L, n + 1, (lua_Debug*)&ar) != 0; ++n) {
        }
        return n;
    }
    static int stacklevel(lua_State* L, int pos) {
        lua_Debug ar;
        if (lua_getstack(L, pos, &ar) != 0) {
            for (; lua_getstack(L, pos + 1, &ar) != 0; ++pos) {
            }
        }
        else if (pos > 0) {
            for (--pos; pos > 0 && lua_getstack(L, pos, &ar) == 0; --pos) {
            }
        }
        return pos;
    }
    void step_in(lua_State* hL) {
        step_current_level = 0;
        step_target_level = 0;
        stepL = 0;
        step_hookmask(hL, LUA_MASKLINE);
    }
    void step_out(lua_State* hL) {
        step_current_level = stacklevel(hL);
        step_target_level = step_current_level - 1;
        stepL = hL;
        step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
    }
    void step_over(lua_State* hL) {
        step_current_level = stacklevel(hL);
        step_target_level = step_current_level;
        stepL = hL;
        step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
    }
    void step_cancel(lua_State* hL) {
        step_current_level = 0;
        step_target_level = 0;
        stepL = 0;
        step_hookmask(hL, 0);
    }
    void step_hook_call(lua_State* hL, lua_Debug* ar) {
        step_current_level++;
        if (step_current_level > step_target_level) {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
        }
        else {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
        }
    }
    void step_hook_return(lua_State* hL, lua_Debug* ar) {
        step_current_level = stacklevel(hL, step_current_level) - 1;
        if (step_current_level > step_target_level) {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
        }
        else {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
        }
    }
    void step_hookmask(lua_State* hL, int mask) {
        if (step_mask != mask) {
            step_mask = mask;
            updatehookmask(hL);
        }
    }

    //
    // exception
    //
    int exception_mask = 0;
#if defined(LUA_HOOKEXCEPTION)
    void exception_hookmask(lua_State* hL, int mask) {
        if (exception_mask != mask) {
            exception_mask = mask;
            updatehookmask(hL);
        }
    }
    void exception_open(lua_State* hL, int enable) {
        exception_hookmask(hL, enable? LUA_MASKEXCEPTION: 0);
    }
    void exception_hook(lua_State* hL, lua_Debug* ar) {
        if (lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            lua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        lua_pushstring(cL, "exception");
        copyvalue(hL, cL);
        if (lua_pcall(cL, 2, 0, 0) != LUA_OK) {
            lua_pop(cL, 1);
            return;
        }
    }
#endif

    //
    // thread
    //
    int thread_mask = 0;
#if defined(LUA_HOOKTHREAD)
    void thread_hookmask(lua_State* hL, int mask) {
        if (thread_mask != mask) {
            thread_mask = mask;
            updatehookmask(hL);
        }
    }
    void thread_open(lua_State* hL, int enable) {
        thread_hookmask(hL, enable? LUA_MASKTHREAD: 0);
    }
    void thread_hook(lua_State* hL, lua_Debug* ar) {
        if (lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            lua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        lua_pushstring(cL, "thread");
        lua_pushlightuserdata(cL, hL);
        if (lua_pcall(cL, 2, 0, 0) != LUA_OK) {
            lua_pop(cL, 1);
            return;
        }
    }
#endif

    //
    // common
    //
    lua_State* cL = 0;
    lua_CFunction oldpanic;
    std::unique_ptr<thunk> sc_hook;
    std::unique_ptr<thunk> sc_panic;
    hookmgr(lua_State* L)
        : cL(L)
        , oldpanic(lua_atpanic(L, 0))
        , sc_hook(thunk_create_hook(
            reinterpret_cast<intptr_t>(this),
            reinterpret_cast<intptr_t>(&hook_callback)
        ))
        , sc_panic(thunk_create_panic(
            reinterpret_cast<intptr_t>(this),
            reinterpret_cast<intptr_t>(&panic_callback),
            reinterpret_cast<intptr_t>(oldpanic)
        ))
    { }

    void probe(lua_State* hL, const char* name) {
        if (lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            lua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        lua_pushstring(cL, name);
        if (lua_pcall(cL, 1, 0, 0) != LUA_OK) {
            lua_pop(cL, 1);
            return;
        }
    }

    int event(lua_State* hL, const char* name) {
        if (lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            lua_pop(cL, 1);
            return -1;
        }
        set_host(cL, hL);
        lua_pushstring(cL, name);
        if (lua_pcall(cL, 1, 1, 0) != LUA_OK) {
            lua_pop(cL, 1);
            return -1;
        }
        if (lua_type(cL, -1) == LUA_TBOOLEAN) {
            int ok = lua_toboolean(cL, -1)? 1 : 0;
            lua_pop(cL, 1);
            return ok;
        }
        lua_pop(cL, 1);
        return -1;
    }

    void panic(lua_State* hL) {
        if (lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            lua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        lua_pushstring(cL, "panic");
        copyvalue(hL, cL);
        if (lua_pcall(cL, 2, 0, 0) != LUA_OK) {
            lua_pop(cL, 1);
            return;
        }
    }

    void hook(lua_State* hL, lua_Debug* ar) {
        switch (ar->event) {
        case LUA_HOOKLINE:
            break;
        case LUA_HOOKCALL:
        case LUA_HOOKTAILCALL:
            break_mask
                ? break_hook_call(hL, ar)
                : step_hook_call(hL, ar)
                ;
            return;
        case LUA_HOOKRET:
            if (update_mask) {
                update_hook(hL);
            }
            if (break_mask & LUA_MASKRET) {
                break_hook_return(hL, ar);
            }
            if (step_mask & LUA_MASKRET) {
                step_hook_return(hL, ar);
            }
            return;
        case LUA_HOOKCOUNT:
            update_hook(hL);
            return;
#if defined(LUA_HOOKEXCEPTION)
        case LUA_HOOKEXCEPTION:
            exception_hook(hL, ar);
            return;
#endif
#if defined(LUA_HOOKTHREAD)
        case LUA_HOOKTHREAD:
            thread_hook(hL, ar);
            return;
#endif
        default:
            return;
        }
        if (lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            lua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        if (step_mask & LUA_MASKLINE) {
            lua_pushstring(cL, "step");
            if (lua_pcall(cL, 1, 0, 0) != LUA_OK) {
                lua_pop(cL, 1);
                return;
            }
        }
        else {
            lua_pushstring(cL, "bp");
            lua_pushinteger(cL, ar->currentline);
            if (lua_pcall(cL, 2, 0, 0) != LUA_OK) {
                lua_pop(cL, 1);
                return;
            }
        }
    }
    void updatehookmask(lua_State* hL) {
        int mask = update_mask | break_mask | step_mask | exception_mask | thread_mask;
        if (mask) {
            lua_sethook(hL, (lua_Hook)sc_hook->data, mask, update_mask? 0xfffff: 0);
        }
        else {
            lua_sethook(hL, 0, 0, 0);
        }
    }
    void setcoroutine(lua_State* hL) {
        updatehookmask(hL);
    }
    
    int update_mask = 0;
    void update_open(lua_State* hL, int enable) {
        update_mask = enable? LUA_MASKRET: 0;
        updatehookmask(hL);
    }
    void update_hook(lua_State* hL) {
        static remotedebug::timer t;
        if (!t.update(200)) {
            return;
        }
        if (lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            lua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        lua_pushstring(cL, "update");
        if (lua_pcall(cL, 1, 0, 0) != LUA_OK) {
            lua_pop(cL, 1);
            return;
        }
    }

    lua_State* hostL = 0;
    void init(lua_State* hL) {
        hostL = hL;
        thunk_bind((intptr_t)hL, (intptr_t)this);
        remotedebug::eventfree::create(hL, lua_freef, this);
    }
    ~hookmgr() {
        if(hostL) {
            remotedebug::eventfree::destroy(hostL);
        }
        lua_sethook(cL, 0, 0, 0);
        lua_atpanic(cL, oldpanic);
    }
    static int clear(lua_State* L) {
        hookmgr* self = (hookmgr*)lua_touserdata(L, 1);
        self->~hookmgr();
        return 0;
    }
    static hookmgr* get_self(lua_State* L) {
        return (hookmgr*)lua_touserdata(L, lua_upvalueindex(1));
    }
    static void hook_callback(hookmgr* mgr, lua_State* hL, lua_Debug* ar) {
        mgr->hook(hL, ar);
    }
    static void lua_freef(void* mgr, void* ptr) {
        ((hookmgr*)mgr)->break_freeobj((Proto*)ptr);
    }
    static void panic_callback(hookmgr* mgr, lua_State* hL) {
        mgr->panic(hL);
    }
};

static int init(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    lua_settop(L, 1);
    hookmgr::get_self(L)->init(get_host(L));
    lua_rawsetp(L, LUA_REGISTRYINDEX, &HOOK_CALLBACK);
    return 0;
}

static int setcoroutine(lua_State* L) {
    hookmgr::get_self(L)->setcoroutine(getthread(L));
    return 0;
}

static int activeline(lua_State* L) {
    lua_State* hL = get_host(L);
    int level = (int)luaL_checkinteger(L, 1);
    lua_Debug ar;
    if (lua_getstack(hL, level, &ar) == 0) {
        return 0;
    }
    if (lua_getinfo(hL, "L", &ar) == 0) {
        lua_pop(hL, 1);
        return 0;
    }
    lua_newtable(L);
    lua_pushnil(hL);
    while (lua_next(hL, -2)) {
        lua_pop(hL, 1);
        lua_pushinteger(L, lua_tointeger(hL, -1));
        lua_pushboolean(L, 1);
        lua_rawset(L, -3);
    }
    lua_pop(hL, 1);
    return 1;
}

static int stacklevel(lua_State* L) {
    lua_State* hL = get_host(L);
    lua_pushinteger(L, hookmgr::stacklevel(hL));
    return 1;
}

static int break_add(lua_State* L) {
    hookmgr::get_self(L)->break_add(get_host(L), checklightudata<Proto>(L, 1));
    return 0;
}

static int break_del(lua_State* L) {
    hookmgr::get_self(L)->break_del(get_host(L), checklightudata<Proto>(L, 1));
    return 0;
}

static int break_open(lua_State* L) {
    hookmgr::get_self(L)->break_open(get_host(L), L);
    return 0;
}

static int break_close(lua_State* L) {
    hookmgr::get_self(L)->break_close(get_host(L));
    return 0;
}

static int break_closeline(lua_State* L) {
    hookmgr::get_self(L)->break_closeline(get_host(L));
    return 0;
}

static int step_in(lua_State* L) {
    hookmgr::get_self(L)->step_in(get_host(L));
    return 0;
}

static int step_out(lua_State* L) {
    hookmgr::get_self(L)->step_out(get_host(L));
    return 0;
}

static int step_over(lua_State* L) {
    hookmgr::get_self(L)->step_over(get_host(L));
    return 0;
}

static int step_cancel(lua_State* L) {
    hookmgr::get_self(L)->step_cancel(get_host(L));
    return 0;
}

static int update_open(lua_State* L) {
    hookmgr::get_self(L)->update_open(get_host(L), lua_toboolean(L, 1));
    return 0;
}

#if defined(LUA_HOOKEXCEPTION)
static int exception_open(lua_State* L) {
    hookmgr::get_self(L)->exception_open(get_host(L), lua_toboolean(L, 1));
    return 0;
}
#endif

#if defined(LUA_HOOKTHREAD)
static int thread_open(lua_State* L) {
    hookmgr::get_self(L)->thread_open(get_host(L), lua_toboolean(L, 1));
    return 0;
}
#endif

extern "C" 
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_remotedebug_hookmgr(lua_State* L) {
    get_host(L);

    lua_newtable(L);
    if (LUA_TUSERDATA != lua_rawgetp(L, LUA_REGISTRYINDEX, &HOOK_MGR)) {
        lua_pop(L, 1);
        hookmgr* thd = (hookmgr*)lua_newuserdata(L, sizeof(hookmgr));
        new (thd) hookmgr(L);

        lua_createtable(L, 0, 1);
        lua_pushcfunction(L, hookmgr::clear);
        lua_setfield(L, -2, "__gc");
        lua_setmetatable(L, -2);

        lua_pushvalue(L, -1);
        lua_rawsetp(L, LUA_REGISTRYINDEX, &HOOK_MGR);
    }

    static luaL_Reg lib[] = {
        { "init", init },
        { "setcoroutine", setcoroutine },
        { "activeline", activeline },
        { "stacklevel", stacklevel },
        { "break_add", break_add },
        { "break_del", break_del },
        { "break_open", break_open },
        { "break_close", break_close },
        { "break_closeline", break_closeline },
        { "step_in", step_in },
        { "step_out", step_out },
        { "step_over", step_over },
        { "step_cancel", step_cancel },
        { "update_open", update_open },
#if defined(LUA_HOOKEXCEPTION)
        { "exception_open", exception_open },
#endif
#if defined(LUA_HOOKTHREAD)
        { "thread_open", thread_open },
#endif
        { NULL, NULL },
    };
    luaL_setfuncs(L, lib, 1);
    return 1;
}

extern "C"
void probe(lua_State* cL, lua_State* hL, const char* name) {
    if (LUA_TUSERDATA != lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_MGR)) {
        lua_pop(cL, 1);
        return;
    }
    ((hookmgr*)lua_touserdata(cL, -1))->probe(hL, name);
    lua_pop(cL, 1);
}

extern "C"
int event(lua_State* cL, lua_State* hL, const char* name) {
    if (LUA_TUSERDATA != lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_MGR)) {
        lua_pop(cL, 1);
        return -1;
    }
    int ok = ((hookmgr*)lua_touserdata(cL, -1))->event(hL, name);
    lua_pop(cL, 1);
    return ok;
}

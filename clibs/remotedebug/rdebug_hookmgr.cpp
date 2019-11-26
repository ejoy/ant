#include "rlua.h"
#include <lstate.h>
#include <assert.h>
#include <stdint.h>
#include <new>
#include <memory>
#include <array>
#include <vector>
#include "rdebug_eventfree.h"
#include "rdebug_timer.h"
#include "thunk/thunk.h"

#if LUA_VERSION_NUM < 504
#define s2v(o) (o)
#endif

static int HOOK_MGR = 0;
static int HOOK_CALLBACK = 0;
#if defined(RDEBUG_DISABLE_THUNK)
static int THUNK_MGR = 0;
#endif

void set_host(rlua_State* L, lua_State* hL);
lua_State* get_host(rlua_State *L);
void copyvalue(lua_State *hL, rlua_State *cL);


#define BPMAP_SIZE (1 << 16)

#define LOG(...) do { \
    FILE* f = fopen("dbg.log", "a"); \
    fprintf(f, __VA_ARGS__); \
    fclose(f); \
} while(0)

template <class T>
static T* checklightudata(rlua_State* L, int idx) {
    rluaL_checktype(L, idx, LUA_TLIGHTUSERDATA);
    return (T*)rlua_touserdata(L, idx);
}

static Proto* ci2proto(CallInfo* ci) {
    StkId func = ci->func;
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

static CallInfo* debug2ci(lua_State* hL, lua_Debug* ar) {
#if LUA_VERSION_NUM >= 502
    return ar->i_ci;
#else
    return hL->base_ci + ar->i_ci;
#endif
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
    std::array<BP, BPMAP_SIZE>     break_map;
    std::array<Proto*, BPMAP_SIZE> break_proto;
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
    void break_open(lua_State* hL) {
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
            rluaL_checkstack(cL, 4, NULL);
            if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
                rlua_pop(cL, 1);
                return false;
            }
            set_host(cL, hL);
            rlua_pushstring(cL, "newproto");
            rlua_pushlightuserdata(cL, p);
            rlua_pushinteger(cL, event != LUA_HOOKRET? 0: 1);
            if (rlua_pcall(cL, 3, 1, 0) != LUA_OK) {
                rlua_pop(cL, 1);
                return false;
            }
            bool exist = rlua_toboolean(cL, -1);
            rlua_pop(cL, 1);
            if (!exist) {
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
        break_update(hL, debug2ci(hL, ar), ar->event);
    }
    void break_hook_return(lua_State* hL, lua_Debug* ar) {
#if LUA_VERSION_NUM >= 502
        break_update(hL, ar->i_ci->previous, ar->event);
#else
        if (!lua_getstack(hL, 1, ar)) {
            return;
        }
        break_update(hL, hL->base_ci + ar->i_ci, ar->event);
#endif
    }
    void break_hookmask(lua_State* hL, int mask) {
        if (break_mask != mask) {
            break_mask = mask;
            updatehookmask(hL);
        }
    }

    // 
    // funcbp
    //
    int funcbp_mask = 0;
    void funcbp_hook(lua_State* hL, lua_Debug* ar) {
        if (0 == lua_getinfo(hL, "f", ar)) {
            return;
        }
        const void* function = lua_topointer(hL, -1);
        lua_pop(hL, 1);

        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            rlua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        rlua_pushstring(cL, "funcbp");
        rlua_pushfstring(cL, "function: %p", function);
        if (rlua_pcall(cL, 2, 0, 0) != LUA_OK) {
            rlua_pop(cL, 1);
        }
    }
    void funcbp_open(lua_State* hL, bool enable) {
        funcbp_hookmask(hL, enable? LUA_MASKCALL: 0);
    }
    void funcbp_hookmask(lua_State* hL, int mask) {
        if (funcbp_mask != mask) {
            funcbp_mask = mask;
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
    
    static int stacklevel(lua_State *L) {
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
    void step_in(lua_State* hL) {
        step_current_level = 0;
        step_target_level = 0;
        stepL = 0;
#if LUA_VERSION_NUM >= 504
        step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
#else
        step_hookmask(hL, LUA_MASKLINE);
#endif
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
        step_current_level = stacklevel(hL) - 1;
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
    lua_CFunction oldpanic = 0;
    std::unique_ptr<thunk> sc_panic;

    void exception_enable(lua_State* hL) {
        oldpanic = lua_atpanic(hostL, 0);
        sc_panic.reset(thunk_create_panic(
            reinterpret_cast<intptr_t>(this),
            reinterpret_cast<intptr_t>(&panic_callback)
        ));
        lua_atpanic(hostL, (lua_CFunction)sc_panic->data);
    }

    void exception_disable(lua_State* hL) {
        lua_atpanic(hL, oldpanic);
    }

    void exception_hookmask(lua_State* hL, int mask) {
        if (exception_mask != mask) {
            if (!exception_mask) {
                exception_enable(hL);
            }
            else {
                exception_disable(hL);
            }
            exception_mask = mask;
            updatehookmask(hL);
        }
    }
    void exception_open(lua_State* hL, int enable) {
        exception_hookmask(hL, enable? LUA_MASKEXCEPTION: 0);
    }
    void exception_hook(lua_State* hL, lua_Debug* ar) {
        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            rlua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        rlua_pushstring(cL, "r_exception");
        copyvalue(hL, cL);
        if (rlua_pcall(cL, 2, 0, 0) != LUA_OK) {
            rlua_pop(cL, 1);
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
        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            rlua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        rlua_pushstring(cL, "r_thread");
        rlua_pushlightuserdata(cL, lua_touserdata(hL, -1));
        rlua_pushinteger(cL, ar->currentline);
        if (rlua_pcall(cL, 3, 0, 0) != LUA_OK) {
            rlua_pop(cL, 1);
            return;
        }
    }
#endif

    //
    // common
    //
    rlua_State* cL = 0;
    std::unique_ptr<thunk> sc_full_hook;
    std::unique_ptr<thunk> sc_idle_hook;

    hookmgr(rlua_State* L)
        : cL(L)
    {
        break_map.fill(BP::None);
        break_proto.fill(0);
    }

    void probe(lua_State* hL, const char* name) {
        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            rlua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        rlua_pushstring(cL, name);
        if (rlua_pcall(cL, 1, 0, 0) != LUA_OK) {
            rlua_pop(cL, 1);
            return;
        }
    }

    int event(lua_State* hL, const char* name) {
        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            rlua_pop(cL, 1);
            return -1;
        }
        set_host(cL, hL);
        rlua_pushstring(cL, name);
        if (rlua_pcall(cL, 1, 1, 0) != LUA_OK) {
            rlua_pop(cL, 1);
            return -1;
        }
        if (rlua_type(cL, -1) == LUA_TBOOLEAN) {
            int ok = rlua_toboolean(cL, -1)? 1 : 0;
            rlua_pop(cL, 1);
            return ok;
        }
        rlua_pop(cL, 1);
        return -1;
    }

    void panic(lua_State* hL) {
        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) == LUA_TFUNCTION) {
            set_host(cL, hL);
            rlua_pushstring(cL, "panic");
            copyvalue(hL, cL);
            if (rlua_pcall(cL, 2, 0, 0) != LUA_OK) {
                rlua_pop(cL, 1);
            }
        }
        else {
            rlua_pop(cL, 1);
        }
        if (oldpanic) {
            oldpanic(hL);
        }
    }

    void full_hook(lua_State* hL, lua_Debug* ar) {
        switch (ar->event) {
        case LUA_HOOKLINE:
            break;
        case LUA_HOOKCALL:
#if LUA_VERSION_NUM >= 502
        case LUA_HOOKTAILCALL:
#else
        case LUA_HOOKTAILRET:
#endif
            if (funcbp_mask) {
                funcbp_hook(hL, ar);
            }
            if (break_mask & LUA_MASKCALL) {
                break_hook_call(hL, ar);
            }
            if (stepL == hL) {
                if (step_mask & LUA_MASKCALL) {
                    step_hook_call(hL, ar);
                }
            }
            return;
        case LUA_HOOKRET:
            if (update_mask) {
                update_hook(hL);
            }
            if (break_mask & LUA_MASKRET) {
                break_hook_return(hL, ar);
            }
            if (stepL == hL) {
                if (step_mask & LUA_MASKRET) {
                    step_hook_return(hL, ar);
                }
            }
#if LUA_VERSION_NUM >= 504
            else if (step_mask & LUA_MASKLINE) {
                // step in
                break;
            }
#endif
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
        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            rlua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        if ((step_mask & LUA_MASKLINE) && (!stepL || stepL == hL)) {
            rlua_pushstring(cL, "step");
            rlua_pushinteger(cL, ar->currentline);
            if (rlua_pcall(cL, 2, 0, 0) != LUA_OK) {
                rlua_pop(cL, 1);
                return;
            }
        }
        else {
            rlua_pushstring(cL, "bp");
            rlua_pushinteger(cL, ar->currentline);
            if (rlua_pcall(cL, 2, 0, 0) != LUA_OK) {
                rlua_pop(cL, 1);
                return;
            }
        }
    }

    void idle_hook(lua_State* hL, lua_Debug* ar) {
        switch (ar->event) {
        case LUA_HOOKRET:
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
    }

    void updatehookmask(lua_State* hL) {
        int mask = break_mask | funcbp_mask;
        if (!stepL || stepL == hL) {
            mask |= step_mask;
        }
        if (mask) {
            lua_sethook(hL, (lua_Hook)sc_full_hook->data, mask | exception_mask | thread_mask, 0);
        }
        else if (update_mask) {
            lua_sethook(hL, (lua_Hook)sc_idle_hook->data, update_mask | exception_mask | thread_mask, 0xfffff);
        }
        else if (exception_mask | thread_mask) {
            lua_sethook(hL, (lua_Hook)sc_idle_hook->data, exception_mask | thread_mask, 0);
        }
        else {
            lua_sethook(hL, 0, 0, 0);
        }
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
        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            rlua_pop(cL, 1);
            return;
        }
        set_host(cL, hL);
        rlua_pushstring(cL, "update");
        if (rlua_pcall(cL, 1, 0, 0) != LUA_OK) {
            rlua_pop(cL, 1);
            return;
        }
    }

    lua_State* hostL = 0;
    void init(lua_State* hL) {
        hostL = hL;
#if defined(RDEBUG_DISABLE_THUNK)
        thunk_set(hL, &THUNK_MGR, (intptr_t)this);
#endif
        sc_full_hook.reset(thunk_create_hook(
            reinterpret_cast<intptr_t>(this),
            reinterpret_cast<intptr_t>(&full_hook_callback)
        ));
        sc_idle_hook.reset(thunk_create_hook(
            reinterpret_cast<intptr_t>(this),
            reinterpret_cast<intptr_t>(&idle_hook_callback)
        ));
        remotedebug::eventfree::create(hL, freeobj_callback, this);
    }
    ~hookmgr() {
        if (!hostL) {
            return;
        }
        remotedebug::eventfree::destroy(hostL);
        lua_sethook(hostL, 0, 0, 0);
#if defined(LUA_HOOKEXCEPTION)
        exception_open(hostL, 0);
#endif
        hostL = 0;
    }
    static int clear(rlua_State* L) {
        hookmgr* self = (hookmgr*)rlua_touserdata(L, 1);
        self->~hookmgr();
        return 0;
    }
    static hookmgr* get_self(rlua_State* L) {
        return (hookmgr*)rlua_touserdata(L, rlua_upvalueindex(1));
    }
    static void freeobj_callback(void* mgr, void* ptr) {
        ((hookmgr*)mgr)->break_freeobj((Proto*)ptr);
    }
#if !defined(RDEBUG_DISABLE_THUNK)
    static void full_hook_callback(hookmgr* mgr, lua_State* hL, lua_Debug* ar) {
        mgr->full_hook(hL, ar);
    }
    static void idle_hook_callback(hookmgr* mgr, lua_State* hL, lua_Debug* ar) {
        mgr->idle_hook(hL, ar);
    }
    static void panic_callback(hookmgr* mgr, lua_State* hL) {
        mgr->panic(hL);
    }
#else
    static int full_hook_callback(lua_State* hL, lua_Debug* ar) {
        hookmgr* mgr = (hookmgr*)thunk_get(hL, &THUNK_MGR);
        mgr->full_hook(hL, ar);
        return 0;
    }
    static int idle_hook_callback(lua_State* hL, lua_Debug* ar) {
        hookmgr* mgr = (hookmgr*)thunk_get(hL, &THUNK_MGR);
        mgr->idle_hook(hL, ar);
        return 0;
    }
    static int panic_callback(lua_State* hL) {
        hookmgr* mgr = (hookmgr*)thunk_get(hL, &THUNK_MGR);
        mgr->panic(hL);
        return 0;
    }
#endif
};

static int init(rlua_State* L) {
    rluaL_checktype(L, 1, LUA_TFUNCTION);
    rlua_settop(L, 1);
    lua_State* hL = get_host(L);
    hookmgr::get_self(L)->init(hL);
    rlua_rawsetp(L, RLUA_REGISTRYINDEX, &HOOK_CALLBACK);
    return 0;
}

static int sethost(rlua_State* L) {
    set_host(L, (lua_State*)rlua_touserdata(L, 1));
    return 0;
}

static int gethost(rlua_State* L) {
    rlua_pushlightuserdata(L, get_host(L));
    return 1;
}

static int updatehookmask(rlua_State* L) {
    hookmgr::get_self(L)->updatehookmask((lua_State*)rlua_touserdata(L, 1));
    return 0;
}

static int activeline(rlua_State* L) {
    lua_State* hL = get_host(L);
    int level = (int)rluaL_checkinteger(L, 1);
    lua_Debug ar;
    if (lua_getstack(hL, level, &ar) == 0) {
        return 0;
    }
    if (lua_getinfo(hL, "L", &ar) == 0) {
        lua_pop(hL, 1);
        return 0;
    }
    rlua_newtable(L);
    lua_pushnil(hL);
    while (lua_next(hL, -2)) {
        lua_pop(hL, 1);
        rlua_pushinteger(L, lua_tointeger(hL, -1));
        rlua_pushboolean(L, 1);
        rlua_rawset(L, -3);
    }
    lua_pop(hL, 1);
    return 1;
}

static int stacklevel(rlua_State* L) {
    lua_State* hL = get_host(L);
    rlua_pushinteger(L, hookmgr::stacklevel(hL));
    return 1;
}

static int break_add(rlua_State* L) {
    hookmgr::get_self(L)->break_add(get_host(L), checklightudata<Proto>(L, 1));
    return 0;
}

static int break_del(rlua_State* L) {
    hookmgr::get_self(L)->break_del(get_host(L), checklightudata<Proto>(L, 1));
    return 0;
}

static int break_open(rlua_State* L) {
    hookmgr::get_self(L)->break_open(get_host(L));
    return 0;
}

static int break_close(rlua_State* L) {
    hookmgr::get_self(L)->break_close(get_host(L));
    return 0;
}

static int break_closeline(rlua_State* L) {
    hookmgr::get_self(L)->break_closeline(get_host(L));
    return 0;
}

static int funcbp_open(rlua_State* L) {
    hookmgr::get_self(L)->funcbp_open(get_host(L), rlua_toboolean(L, 1));
    return 0;
}

static int step_in(rlua_State* L) {
    hookmgr::get_self(L)->step_in(get_host(L));
    return 0;
}

static int step_out(rlua_State* L) {
    hookmgr::get_self(L)->step_out(get_host(L));
    return 0;
}

static int step_over(rlua_State* L) {
    hookmgr::get_self(L)->step_over(get_host(L));
    return 0;
}

static int step_cancel(rlua_State* L) {
    hookmgr::get_self(L)->step_cancel(get_host(L));
    return 0;
}

static int update_open(rlua_State* L) {
    hookmgr::get_self(L)->update_open(get_host(L), rlua_toboolean(L, 1));
    return 0;
}

#if defined(LUA_HOOKEXCEPTION)
static int exception_open(rlua_State* L) {
    hookmgr::get_self(L)->exception_open(get_host(L), rlua_toboolean(L, 1));
    return 0;
}
#endif

#if defined(LUA_HOOKTHREAD)
static int thread_open(rlua_State* L) {
    hookmgr::get_self(L)->thread_open(get_host(L), rlua_toboolean(L, 1));
    return 0;
}
#endif

RLUA_FUNC
int luaopen_remotedebug_hookmgr(rlua_State* L) {
    get_host(L);

    rlua_newtable(L);
    if (LUA_TUSERDATA != rlua_rawgetp(L, RLUA_REGISTRYINDEX, &HOOK_MGR)) {
        rlua_pop(L, 1);
        hookmgr* thd = (hookmgr*)rlua_newuserdata(L, sizeof(hookmgr));
        new (thd) hookmgr(L);

        rlua_createtable(L, 0, 1);
        rlua_pushcfunction(L, hookmgr::clear);
        rlua_setfield(L, -2, "__gc");
        rlua_setmetatable(L, -2);

        rlua_pushvalue(L, -1);
        rlua_rawsetp(L, RLUA_REGISTRYINDEX, &HOOK_MGR);
    }

    static rluaL_Reg lib[] = {
        { "init", init },
        { "sethost", sethost },
        { "gethost", gethost },
        { "updatehookmask", updatehookmask },
        { "activeline", activeline },
        { "stacklevel", stacklevel },
        { "break_add", break_add },
        { "break_del", break_del },
        { "break_open", break_open },
        { "break_close", break_close },
        { "break_closeline", break_closeline },
        { "funcbp_open", funcbp_open },
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
    rluaL_setfuncs(L, lib, 1);
    return 1;
}

void probe(rlua_State* cL, lua_State* hL, const char* name) {
    if (LUA_TUSERDATA != rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_MGR)) {
        rlua_pop(cL, 1);
        return;
    }
    lu_byte oldah = hL->allowhook;
    hL->allowhook = 0;
    ((hookmgr*)rlua_touserdata(cL, -1))->probe(hL, name);
    hL->allowhook = oldah;
    rlua_pop(cL, 1);
}

int event(rlua_State* cL, lua_State* hL, const char* name) {
    if (LUA_TUSERDATA != rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_MGR)) {
        rlua_pop(cL, 1);
        return -1;
    }
    lu_byte oldah = hL->allowhook;
    hL->allowhook = 0;
    int ok = ((hookmgr*)rlua_touserdata(cL, -1))->event(hL, name);
    hL->allowhook = oldah;
    rlua_pop(cL, 1);
    return ok;
}

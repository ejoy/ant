#include <bee/utility/dynarray.h>

#include <chrono>
#include <cstdint>
#include <memory>

#include "compat/internal.h"
#include "rdebug_debughost.h"
#include "rdebug_eventfree.h"
#include "rdebug_lua.h"
#include "thunk/thunk.h"
#include "util/flatmap.h"

#if LUA_VERSION_NUM >= 502
#    include <lstate.h>
#    if defined(LUA_VERSION_LATEST)
#        define LUA_STKID(s) s.p
#    else
#        define LUA_STKID(s) s
#    endif
#endif

class bpmap {
public:
    enum class status {
        None,
        Break,
        Ignore,
    };

    void set(void* proto, status status) {
        switch (status) {
        case status::None:
            m_flatmap.erase(tokey(proto));
            break;
        case status::Break:
            m_flatmap.insert_or_assign(tokey(proto), true);
            break;
        case status::Ignore:
            m_flatmap.insert_or_assign(tokey(proto), false);
            break;
        }
    }

    status get(void* proto) const noexcept {
        const bool* v = m_flatmap.find(tokey(proto));
        if (v) {
            return *v ? status::Break : status::Ignore;
        }
        return status::None;
    }

private:
    intptr_t tokey(void* proto) const noexcept {
        return reinterpret_cast<intptr_t>(proto);
    }

    // TODO: bullet size可以压缩到一个int64_t
    luadebug::flatmap<intptr_t, bool> m_flatmap;
};

static int HOOK_MGR      = 0;
static int HOOK_CALLBACK = 0;
#if defined(LUADEBUG_DISABLE_THUNK)
static int THUNK_MGR = 0;
#endif

static void push_callback(luadbg_State* L) {
    if (luadbg_rawgetp(L, LUADBG_REGISTRYINDEX, &HOOK_CALLBACK) != LUADBG_TFUNCTION) {
        luadbgL_error(L, "miss hook callback");
    }
}

namespace luadebug::visitor {
    int copy_to_dbg_ref(lua_State* hL, luadbg_State* L);
    void registry_unref(lua_State* hL, int ref);
}

#define LOG(...)                         \
    do {                                 \
        FILE* f = fopen("dbg.log", "a"); \
        fprintf(f, __VA_ARGS__);         \
        fclose(f);                       \
    } while (0)

template <class T>
static T* checklightudata(luadbg_State* L, int idx) {
    luadbgL_checktype(L, idx, LUA_TLIGHTUSERDATA);
    return (T*)luadbg_touserdata(L, idx);
}

struct timer {
    std::chrono::time_point<std::chrono::system_clock> last = std::chrono::system_clock::now();
    bool update(int ms) {
        auto now  = std::chrono::system_clock::now();
        auto diff = std::chrono::duration_cast<std::chrono::milliseconds>(now - last);
        if (diff.count() > ms) {
            last = now;
            return true;
        }
        return false;
    }
};

struct hookmgr {
    //
    // break
    //
    bpmap break_proto;
    int break_mask = 0;

    void break_add(lua_State* hL, Proto* p) {
        break_proto.set(p, bpmap::status::Break);
    }
    void break_del(lua_State* hL, Proto* p) {
        break_proto.set(p, bpmap::status::Ignore);
    }
    void break_freeobj(Proto* p) {
        break_proto.set(p, bpmap::status::None);
    }
    void break_open(lua_State* hL, bool enable) {
        if (enable)
            break_update(hL, lua_getcallinfo(hL), LUA_HOOKCALL);
        else
            break_hookmask(hL, 0);
    }
    void break_openline(lua_State* hL) {
        break_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
    }
    void break_closeline(lua_State* hL) {
        break_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
    }
    bool break_new(lua_State* hL, Proto* p, int event) {
        break_del(hL, p);

        luadbgL_checkstack(L, 4, NULL);
        push_callback(L);
        luadebug::debughost::set(L, hL);
        luadbg_pushstring(L, "newproto");
        luadbg_pushlightuserdata(L, p);
        luadbg_pushinteger(L, event != LUA_HOOKRET ? 0 : 1);
        if (luadbg_pcall(L, 3, 0, 0) != LUADBG_OK) {
            luadbg_pop(L, 1);
            return false;
        }
        return break_has(hL, p, event);
    }
    bool break_has(lua_State* hL, Proto* p, int event) {
        if (!p) {
            return false;
        }
        auto status = break_proto.get(p);
        if (status == bpmap::status::None) {
            return break_new(hL, p, event);
        }
        return status == bpmap::status::Break;
    }
    void break_update(lua_State* hL, CallInfo* ci, int event) {
        if (break_has(hL, lua_ci2proto(ci), event)) {
            break_openline(hL);
        }
        else {
            break_closeline(hL);
        }
    }
    void break_hook_call(lua_State* hL, lua_Debug* ar) {
#if LUA_VERSION_NUM < 502
        if (ar->i_ci == 0) {
            return;
        }
#endif
        break_update(hL, lua_debug2ci(hL, ar), ar->event);
    }
    void break_hook_return(lua_State* hL, lua_Debug* ar) {
#if LUA_VERSION_NUM >= 502
        break_update(hL, ar->i_ci->previous, ar->event);
#else
        if (!lua_getstack(hL, 1, ar)) {
            return;
        }
        if (ar->i_ci == 0) {
            return;
        }
        break_update(hL, lua_debug2ci(hL, ar), ar->event);
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

        push_callback(L);
        luadebug::debughost::set(L, hL);
        luadbg_pushstring(L, "funcbp");
        luadbg_pushfstring(L, "function: %p", function);
        if (luadbg_pcall(L, 2, 0, 0) != LUADBG_OK) {
            luadbg_pop(L, 1);
        }
    }
    void funcbp_open(lua_State* hL, bool enable) {
        funcbp_hookmask(hL, enable ? LUA_MASKCALL : 0);
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
    lua_State* stepL       = 0;
    int step_current_level = 0;
    int step_target_level  = 0;
    int step_mask          = 0;

    void step_in(lua_State* hL) {
        step_current_level = 0;
        step_target_level  = 0;
        stepL              = 0;
#if LUA_VERSION_NUM >= 504
        step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
#else
        step_hookmask(hL, LUA_MASKLINE);
#endif
    }
    void step_out(lua_State* hL) {
        step_current_level = lua_stacklevel(hL);
        step_target_level  = step_current_level - 1;
        stepL              = hL;
        step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
    }
    void step_over(lua_State* hL) {
        step_current_level = lua_stacklevel(hL);
        step_target_level  = step_current_level;
        stepL              = hL;
        step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
    }
    void step_cancel(lua_State* hL) {
        step_current_level = 0;
        step_target_level  = 0;
        stepL              = 0;
        step_hookmask(hL, 0);
    }
    void step_hook_call(lua_State* hL, lua_Debug* ar) {
#ifdef LUAJIT_VERSION
        // because luajit enter the hook when call c function but not enter hook when return c funtion,so skip c function
        if (!lua_isluafunc(hL, ar))
            return;
#endif
        step_current_level++;
        if (step_current_level > step_target_level) {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
        }
        else {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
        }
    }
    void step_hook_return(lua_State* hL, lua_Debug* ar) {
        step_current_level = lua_stacklevel(hL) - 1;
        if (step_current_level > step_target_level) {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
        }
        else {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
        }
    }
#ifdef LUAJIT_VERSION
    void step_hook_line(lua_State* hL, lua_Debug* ar) {
        step_current_level = lua_stacklevel(hL);
        if (step_current_level > step_target_level) {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
        }
        else {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
        }
    }
#endif
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
        exception_hookmask(hL, enable ? LUA_MASKEXCEPTION : 0);
    }
    void exception_hook(lua_State* hL, lua_Debug* ar) {
        push_callback(L);
        int errcode;
        luadebug::debughost::set(L, hL);
        luadbg_pushstring(L, "exception");
#    if LUA_VERSION_NUM >= 504
        LUA_STKID(hL->top) = LUA_STKID(hL->stack) + ar->currentline;
        errcode            = ar->i_ci->u2.transferinfo.ntransfer;
#    else
        errcode = ar->currentline;
#    endif
        int ref = luadebug::visitor::copy_to_dbg_ref(hL, L);
        luadbg_pushinteger(L, errcode);
        if (luadbg_pcall(L, 3, 0, 0) != LUADBG_OK) {
            luadbg_pop(L, 1);
        }
        luadebug::visitor::registry_unref(hL, ref);
    }
#endif

    //
    // thread
    //
    int thread_mask = 0;
    luadebug::flatmap<lua_State*, lua_State*> coroutine_tree;
#if defined(LUA_HOOKTHREAD)
    void thread_hookmask(lua_State* hL, int mask) {
        if (thread_mask != mask) {
            thread_mask = mask;
            updatehookmask(hL);
        }
    }
    void thread_open(lua_State* hL, int enable) {
        thread_hookmask(hL, enable ? LUA_MASKTHREAD : 0);
    }
    void thread_hook(lua_State* co, lua_Debug* ar) {
        lua_State* from = (lua_State*)lua_touserdata(co, -1);
        if (from) {
            int type = ar->currentline;
            if (type == 0) {
                coroutine_tree.insert_or_assign(co, from);
            }
            else if (type == 1) {
                coroutine_tree.erase(from);
            }
        }
        updatehookmask(co);
    }
    lua_State* coroutine_from(lua_State* co) {
        auto r = coroutine_tree.find(co);
        if (!r) {
            return nullptr;
        }
        return *r;
    }
#endif

    //
    // common
    //
    luadbg_State* L = 0;
    std::unique_ptr<thunk> sc_full_hook;
    std::unique_ptr<thunk> sc_idle_hook;
    void* eventfree = nullptr;

    hookmgr(luadbg_State* L)
        : L(L) {}

#ifdef LUAJIT_VERSION
    bool last_hook_call_in_c = false;
#endif
    void full_hook(lua_State* hL, lua_Debug* ar) {
        switch (ar->event) {
        case LUA_HOOKLINE:
#ifdef LUAJIT_VERSION
            if (last_hook_call_in_c) {
#    if defined(LUA_HOOKTHREAD)
                thread_mask &= (~LUA_MASKTHREAD);
#    endif
                updatehookmask(hL);
                last_hook_call_in_c = false;
                if (break_mask)
                    break_hook_call(hL, ar);
            }
            if (stepL == hL) {
                if (step_mask & LUA_MASKRET) {
                    step_hook_line(hL, ar);
                }
            }
            if (!((step_mask & LUA_MASKLINE) && (!stepL || stepL == hL)) && !(break_mask & LUA_MASKLINE))
                return;
#endif
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
#ifdef LUAJIT_VERSION
            last_hook_call_in_c = !lua_isluafunc(hL, ar);
            if (last_hook_call_in_c) {
                thread_mask |= LUA_MASKLINE;
                updatehookmask(hL);

                if (update_mask)
                    update_hook(hL);
            }
#endif
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
        push_callback(L);
        luadebug::debughost::set(L, hL);
        if ((step_mask & LUA_MASKLINE) && (!stepL || stepL == hL)) {
            luadbg_pushstring(L, "step");
            luadbg_pushinteger(L, ar->currentline);
            if (luadbg_pcall(L, 2, 0, 0) != LUADBG_OK) {
                luadbg_pop(L, 1);
                return;
            }
        }
        else {
            luadbg_pushstring(L, "bp");
            luadbg_pushinteger(L, ar->currentline);
            if (luadbg_pcall(L, 2, 0, 0) != LUADBG_OK) {
                luadbg_pop(L, 1);
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

    void sethook(lua_State* hL, lua_Hook func, int mask, int count) {
        lua_sethook(hL, func, mask, count);
#ifndef LUAJIT_VERSION
        // luajit hook info in global_state
        lua_State* mainL = lua_getmainthread(hL);
        if (mainL != hL) {
            lua_sethook(mainL, func, mask, count);
        }
#endif
    }

    void updatehookmask(lua_State* hL) {
        int mask = break_mask | funcbp_mask;
        if (!stepL || stepL == hL) {
            mask |= step_mask;
        }
        if (mask) {
            sethook(hL, (lua_Hook)sc_full_hook->data, mask | exception_mask | thread_mask, 0);
        }
        else if (update_mask) {
            sethook(hL, (lua_Hook)sc_idle_hook->data, update_mask | exception_mask | thread_mask, 0xfffff);
        }
        else if (exception_mask | thread_mask) {
            sethook(hL, (lua_Hook)sc_idle_hook->data, exception_mask | thread_mask, 0);
        }
        else {
            sethook(hL, 0, 0, 0);
        }
    }

    int update_mask = 0;
    timer update_timer;
    void update_open(lua_State* hL, int enable) {
        update_mask = enable ? LUA_MASKRET : 0;
        updatehookmask(hL);
    }
    void update_hook(lua_State* hL) {
        if (!update_timer.update(200)) {
            return;
        }
        push_callback(L);
        luadebug::debughost::set(L, hL);
        luadbg_pushstring(L, "update");
        if (luadbg_pcall(L, 1, 0, 0) != LUADBG_OK) {
            luadbg_pop(L, 1);
            return;
        }
    }

    lua_State* hL = 0;
    void init(lua_State* hL) {
        this->hL = hL;
#if defined(LUADEBUG_DISABLE_THUNK)
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
        eventfree = luadebug::eventfree::create(hL, freeobj_callback, this);
    }
    ~hookmgr() {
        if (!hL) {
            return;
        }
        luadebug::eventfree::destroy(hL, eventfree);
        lua_sethook(hL, 0, 0, 0);
#if defined(LUA_HOOKEXCEPTION)
        exception_open(hL, 0);
#endif
        hL = 0;
    }
    static int clear(luadbg_State* L) {
        hookmgr* self = (hookmgr*)luadbg_touserdata(L, 1);
        self->~hookmgr();
        return 0;
    }
    static hookmgr* get_self(luadbg_State* L) {
        return (hookmgr*)luadbg_touserdata(L, luadbg_upvalueindex(1));
    }
    static void freeobj_callback(void* mgr, void* ptr) {
        ((hookmgr*)mgr)->break_freeobj((Proto*)ptr);
    }
#if !defined(LUADEBUG_DISABLE_THUNK)
    static void full_hook_callback(hookmgr* mgr, lua_State* hL, lua_Debug* ar) {
        mgr->full_hook(hL, ar);
    }
    static void idle_hook_callback(hookmgr* mgr, lua_State* hL, lua_Debug* ar) {
        mgr->idle_hook(hL, ar);
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
#endif
};

static int init(luadbg_State* L) {
    luadbgL_checktype(L, 1, LUA_TFUNCTION);
    luadbg_settop(L, 1);
    luadbg_rawsetp(L, LUADBG_REGISTRYINDEX, &HOOK_CALLBACK);
    lua_State* hL = luadebug::debughost::get(L);
    hookmgr::get_self(L)->init(hL);
    return 0;
}

static int sethost(luadbg_State* L) {
    luadbgL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    luadebug::debughost::set(L, (lua_State*)luadbg_touserdata(L, 1));
    return 0;
}

static int gethost(luadbg_State* L) {
    luadbg_pushlightuserdata(L, luadebug::debughost::get(L));
    return 1;
}

static int updatehookmask(luadbg_State* L) {
    hookmgr::get_self(L)->updatehookmask((lua_State*)luadbg_touserdata(L, 1));
    return 0;
}

static int stacklevel(luadbg_State* L) {
    lua_State* hL = luadebug::debughost::get(L);
    luadbg_pushinteger(L, lua_stacklevel(hL));
    return 1;
}

static int break_add(luadbg_State* L) {
    hookmgr::get_self(L)->break_add(luadebug::debughost::get(L), checklightudata<Proto>(L, 1));
    return 0;
}

static int break_del(luadbg_State* L) {
    hookmgr::get_self(L)->break_del(luadebug::debughost::get(L), checklightudata<Proto>(L, 1));
    return 0;
}

static int break_open(luadbg_State* L) {
    hookmgr::get_self(L)->break_open(luadebug::debughost::get(L), luadbg_toboolean(L, 1));
    return 0;
}

static int break_closeline(luadbg_State* L) {
    hookmgr::get_self(L)->break_closeline(luadebug::debughost::get(L));
    return 0;
}

static int funcbp_open(luadbg_State* L) {
    hookmgr::get_self(L)->funcbp_open(luadebug::debughost::get(L), luadbg_toboolean(L, 1));
    return 0;
}

static int step_in(luadbg_State* L) {
    hookmgr::get_self(L)->step_in(luadebug::debughost::get(L));
    return 0;
}

static int step_out(luadbg_State* L) {
    hookmgr::get_self(L)->step_out(luadebug::debughost::get(L));
    return 0;
}

static int step_over(luadbg_State* L) {
    hookmgr::get_self(L)->step_over(luadebug::debughost::get(L));
    return 0;
}

static int step_cancel(luadbg_State* L) {
    hookmgr::get_self(L)->step_cancel(luadebug::debughost::get(L));
    return 0;
}

static int update_open(luadbg_State* L) {
    hookmgr::get_self(L)->update_open(luadebug::debughost::get(L), luadbg_toboolean(L, 1));
    return 0;
}

#if defined(LUA_HOOKEXCEPTION)
static int exception_open(luadbg_State* L) {
    hookmgr::get_self(L)->exception_open(luadebug::debughost::get(L), luadbg_toboolean(L, 1));
    return 0;
}
#endif

#if defined(LUA_HOOKTHREAD)
static int thread_open(luadbg_State* L) {
    hookmgr::get_self(L)->thread_open(luadebug::debughost::get(L), luadbg_toboolean(L, 1));
    return 0;
}
static int coroutine_from(luadbg_State* L) {
    luadbgL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    lua_State* from = hookmgr::get_self(L)->coroutine_from((lua_State*)luadbg_touserdata(L, 1));
    if (!from) {
        return 0;
    }
    luadbg_pushlightuserdata(L, from);
    return 1;
}
#endif

LUADEBUG_FUNC
int luaopen_luadebug_hookmgr(luadbg_State* L) {
    luadebug::debughost::get(L);

    luadbg_newtable(L);
    if (LUADBG_TUSERDATA != luadbg_rawgetp(L, LUADBG_REGISTRYINDEX, &HOOK_MGR)) {
        luadbg_pop(L, 1);
        hookmgr* thd = (hookmgr*)luadbg_newuserdata(L, sizeof(hookmgr));
        new (thd) hookmgr(L);

        luadbg_createtable(L, 0, 1);
        luadbg_pushcfunction(L, hookmgr::clear);
        luadbg_setfield(L, -2, "__gc");
        luadbg_setmetatable(L, -2);

        luadbg_pushvalue(L, -1);
        luadbg_rawsetp(L, LUADBG_REGISTRYINDEX, &HOOK_MGR);
    }

    static luadbgL_Reg lib[] = {
        { "init", init },
        { "sethost", sethost },
        { "gethost", gethost },
        { "updatehookmask", updatehookmask },
        { "stacklevel", stacklevel },
        { "break_add", break_add },
        { "break_del", break_del },
        { "break_open", break_open },
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
        { "coroutine_from", coroutine_from },
#endif
        { NULL, NULL },
    };
    luadbgL_setfuncs(L, lib, 1);
    return 1;
}

static bool call_event(luadbg_State* L, int nargs) {
    if (luadbg_pcall(L, 1 + nargs, 1, 0) != LUADBG_OK) {
        luadbg_pop(L, 1);
        return false;
    }
    if (luadbg_type(L, -1) != LUA_TBOOLEAN) {
        luadbg_pop(L, 1);
        return false;
    }
    bool ok = !!luadbg_toboolean(L, -1);
    luadbg_pop(L, 1);
    return ok;
}

bool event(luadbg_State* L, lua_State* hL, const char* name, int start) {
    if (luadbg_rawgetp(L, LUADBG_REGISTRYINDEX, &HOOK_CALLBACK) != LUADBG_TFUNCTION) {
        // TODO cache event?
        luadbg_pop(L, 1);
        return false;
    }
    int nargs = lua_gettop(hL) - start + 1;
    luadebug::debughost::set(L, hL);
    luadbg_pushstring(L, name);
    if (nargs <= 0) {
        return call_event(L, 0);
    }
    bee::dynarray<int> refs(nargs);
    for (int i = 0; i < nargs; ++i) {
        lua_pushvalue(hL, start + i);
        refs[i] = luadebug::visitor::copy_to_dbg_ref(hL, L);
        lua_pop(hL, 1);
    }
    bool ok = call_event(L, nargs);
    for (int i = 0; i < nargs; ++i) {
        luadebug::visitor::registry_unref(hL, refs[i]);
    }
    return ok;
}

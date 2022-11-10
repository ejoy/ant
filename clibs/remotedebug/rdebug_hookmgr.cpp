#include "rlua.h"
#include <assert.h>
#include <stdint.h>
#include <new>
#include <memory>
#include <array>
#include <chrono>
#include <vector>
#include <unordered_map>
#include "rdebug_eventfree.h"
#include "thunk/thunk.h"
#if !defined(RDEBUG_USE_STDMAP)
#include "rdebug_flatmap.h"
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
#if defined(RDEBUG_USE_STDMAP)
        auto v = m_flatmap.find(tokey(proto));
        if (v != m_flatmap.end()) {
            return v->second? status::Break: status::Ignore;
        }
        return status::None;
#else
        const bool* v = m_flatmap.find(tokey(proto));
        if (v) {
            return *v? status::Break: status::Ignore;
        }
        return status::None;
#endif
    }

private:
    intptr_t tokey(void* proto) const noexcept {
        return reinterpret_cast<intptr_t>(proto);
    }

#if defined(RDEBUG_USE_STDMAP)
    std::unordered_map<intptr_t, bool> m_flatmap;
#else
    // TODO: bullet size可以压缩到一个int64_t
    remotedebug::flatmap<intptr_t, bool> m_flatmap;
#endif
};

#include "rluaobject.h"
#ifdef LUAJIT_VERSION
#include <lj_arch.h>
#include <lj_frame.h>
#include <lj_obj.h>
#include <lj_debug.h>
using lu_byte = uint8_t;
using CallInfo = TValue;
cTValue *lj_debug_frame(lua_State *L, int level, int *size)
{
  cTValue *frame, *nextframe, *bot = tvref(L->stack)+LJ_FR2;
  /* Traverse frames backwards. */
  for (nextframe = frame = L->base-1; frame > bot; ) {
    if (frame_gc(frame) == obj2gco(L))
      level++;  /* Skip dummy frames. See lj_err_optype_call(). */
    if (level-- == 0) {
      *size = (int)(nextframe - frame);
      return frame;  /* Level found. */
    }
    nextframe = frame;
    if (frame_islua(frame)) {
      frame = frame_prevl(frame);
    } else {
      if (frame_isvarg(frame))
	level++;  /* Skip vararg pseudo-frame. */
      frame = frame_prevd(frame);
    }
  }
  *size = level;
  return NULL;  /* Level not found. */
}
#endif

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
int copy_value(lua_State* from, rlua_State* to, bool ref);
void unref_value(lua_State* from, int ref);

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
#ifdef LUAJIT_VERSION
    GCfunc *func = frame_func(ci);

    if (!isluafunc(func))
        return 0;
    return funcproto(func);
#else
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
#endif
}

static CallInfo* debug2ci(lua_State* hL, lua_Debug* ar) {
#if LUA_VERSION_NUM >= 502
    return ar->i_ci;
#else
#ifdef LUAJIT_VERSION
    uint32_t offset = (uint32_t)ar->i_ci & 0xffff;
    return tvref(hL->stack) + offset;
#else
    return hL->base_ci + ar->i_ci;
#endif
#endif
}

CallInfo *get_callinfo(lua_State *L, uint16_t level = 0)
{
#ifdef LUAJIT_VERSION
    int size;
    return const_cast<CallInfo *>(lj_debug_frame(L, level, &size));
#else
    return L->ci;
#endif
}

struct timer {
    std::chrono::time_point<std::chrono::system_clock> last = std::chrono::system_clock::now();
    bool update(int ms) {
        auto now = std::chrono::system_clock::now();
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
    int   break_mask = 0;

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
            break_update(hL, get_callinfo(hL), LUA_HOOKCALL);
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

        rluaL_checkstack(cL, 4, NULL);
        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            rlua_pop(cL, 1);
            return false;
        }
        set_host(cL, hL);
        rlua_pushstring(cL, "newproto");
        rlua_pushlightuserdata(cL, p);
        rlua_pushinteger(cL, event != LUA_HOOKRET? 0: 1);
        if (rlua_pcall(cL, 3, 0, 0) != LUA_OK) {
            rlua_pop(cL, 1);
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
        if (break_has(hL, ci2proto(ci), event)) {
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
        break_update(hL, debug2ci(hL, ar), ar->event);
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
        break_update(hL, debug2ci(hL, ar), ar->event);
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
#elif defined(LUAJIT_VERSION)

        cTValue *frame, *nextframe, *bot = tvref(L->stack) + LJ_FR2;
        /* Traverse frames backwards. */
        for (nextframe = frame = L->base - 1; frame > bot;)
        {
            if (frame_gc(frame) == obj2gco(L)) {
                level--;
            }
            level++;
            nextframe = frame;
            if (frame_islua(frame))
            {
                frame = frame_prevl(frame);
            }
            else
            {
                if (frame_isvarg(frame))
                    level--; /* Skip vararg pseudo-frame. */
                frame = frame_prevd(frame);
            }
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
#ifdef LUAJIT_VERSION
        // because luajit enter the hook when call c function but not enter hook when return c funtion,so skip c function
        if(!isluafunc(frame_func(debug2ci(hL, ar))))
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
        step_current_level = stacklevel(hL) - 1;
        if (step_current_level > step_target_level) {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
        }
        else {
            step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
        }
    }
#ifdef LUAJIT_VERSION
    void step_hook_line(lua_State* hL, lua_Debug* ar) {
        step_current_level = stacklevel(hL);
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
        exception_hookmask(hL, enable? LUA_MASKEXCEPTION: 0);
    }
    void exception_hook(lua_State* hL, lua_Debug* ar) {
        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            rlua_pop(cL, 1);
            return;
        }
		int errcode;
        set_host(cL, hL);
        rlua_pushstring(cL, "exception");
#if LUA_VERSION_NUM >= 504
		hL->top = hL->stack + ar->currentline;
		errcode = ar->i_ci->u2.transferinfo.ntransfer;
#else
		errcode = ar->currentline;
#endif
        int ref = copy_value(hL, cL, true);
        rlua_pushinteger(cL, errcode);
        if (rlua_pcall(cL, 3, 0, 0) != LUA_OK) {
            rlua_pop(cL, 1);
        }
        unref_value(hL, ref);
    }
#endif

    //
    // thread
    //
    int thread_mask = 0;
    std::unordered_map<lua_State*, lua_State*> coroutine_tree;
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
    void thread_hook(lua_State* co, lua_Debug* ar) {
        lua_State* from = (lua_State*)lua_touserdata(co, -1);
        if (from) {
            int type = ar->currentline;
            if (type == 0) {
                coroutine_tree[co] = from;
            }
            else if (type == 1) {
                coroutine_tree.erase(from);
            }
        }
        updatehookmask(co);
    }
    lua_State* coroutine_from(lua_State* co) {
        auto it = coroutine_tree.find(co);
        if (it == coroutine_tree.end()) {
            return nullptr;
        }
        return it->second;
    }
#endif

    //
    // common
    //
    rlua_State* cL = 0;
    std::unique_ptr<thunk> sc_full_hook;
    std::unique_ptr<thunk> sc_idle_hook;
    void* eventfree = nullptr;

    hookmgr(rlua_State* L)
        : cL(L)
    { }

    int call_event(int nargs) {
        if (rlua_pcall(cL, 1 + nargs, 1, 0) != LUA_OK) {
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

    int event(lua_State* hL, const char* name, int start) {
        if (rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_CALLBACK) != LUA_TFUNCTION) {
            rlua_pop(cL, 1);
            return -1;
        }
        int nargs = lua_gettop(hL) - start + 1;
        set_host(cL, hL);
        rlua_pushstring(cL, name);
        if (nargs <= 0) {
            return call_event(0);
        }
        std::vector<int> refs; refs.resize(nargs);
        for (int i = 0; i < nargs; ++i) {
            lua_pushvalue(hL, start + i);
            refs[i] = copy_value(hL, cL, true);
            lua_pop(hL, 1);
        }
        int nres = call_event(nargs);
        for (int i = 0; i < nargs; ++i) {
            unref_value(hL, refs[i]);
        }
        return nres;
    }
#ifdef LUAJIT_VERSION
	bool last_hook_call_in_c = false;
#endif
    void full_hook(lua_State* hL, lua_Debug* ar) {
        switch (ar->event) {
        case LUA_HOOKLINE:
#ifdef LUAJIT_VERSION
			if (last_hook_call_in_c){
				thread_mask &= (~LUA_MASKTHREAD);
				updatehookmask(hL);
				last_hook_call_in_c = false;
			}
            if (stepL == hL) {
                if (step_mask & LUA_MASKRET) {
                    step_hook_line(hL, ar);
                }
            }
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
			last_hook_call_in_c = !isluafunc(frame_func(debug2ci(hL, ar)));
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

    lua_State* getmainthread(lua_State* L) {
#if !defined(RDEBUG_FAST) && LUA_VERSION_NUM >= 502
        lua_rawgeti(L,  LUA_REGISTRYINDEX, LUA_RIDX_MAINTHREAD);
        lua_State* mL = lua_tothread(L, -1);
        lua_pop(L, 1);
        return mL;
#elif defined(LUAJIT_VERSION)
        return mainthread(G(L));
#else
        return L->l_G->mainthread;
#endif
    }

    void sethook(lua_State* L, lua_Hook func, int mask, int count) {
        lua_sethook(L, func, mask, count);
#ifndef LUAJIT_VERSION  //luajit hook info in global_state
        lua_State* mainL = getmainthread(L);
        if (mainL != L) {
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
        update_mask = enable? LUA_MASKRET: 0;
        updatehookmask(hL);
    }
    void update_hook(lua_State* hL) {
        if (!update_timer.update(200)) {
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
        eventfree = remotedebug::eventfree::create(hL, freeobj_callback, this);
    }
    ~hookmgr() {
        if (!hostL) {
            return;
        }
        remotedebug::eventfree::destroy(hostL, eventfree);
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

static int init(rlua_State* L) {
    rluaL_checktype(L, 1, LUA_TFUNCTION);
    rlua_settop(L, 1);
    lua_State* hL = get_host(L);
    hookmgr::get_self(L)->init(hL);
    rlua_rawsetp(L, RLUA_REGISTRYINDEX, &HOOK_CALLBACK);
    return 0;
}

static int sethost(rlua_State* L) {
    rluaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
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
    hookmgr::get_self(L)->break_open(get_host(L), rlua_toboolean(L, 1));
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
static int coroutine_from(rlua_State* L) {
    rluaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    lua_State* from = hookmgr::get_self(L)->coroutine_from((lua_State*)rlua_touserdata(L, 1));
    if (!from) {
        return 0;
    }
    rlua_pushlightuserdata(L, from);
    return 1;
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
    rluaL_setfuncs(L, lib, 1);
    return 1;
}

int event(rlua_State* cL, lua_State* hL, const char* name, int start) {
    if (LUA_TUSERDATA != rlua_rawgetp(cL, RLUA_REGISTRYINDEX, &HOOK_MGR)) {
        rlua_pop(cL, 1);
        return -1;
    }
    int ok = ((hookmgr*)rlua_touserdata(cL, -1))->event(hL, name, start);
    rlua_pop(cL, 1);
    return ok;
}

int debug_pcall(lua_State *L, int nargs, int nresults, int errfunc)
{
#ifdef LUAJIT_VERSION
    global_State *g = G(L);
    bool needClean = !hook_active(g);
    hook_enter(g);
    int ok = lua_pcall(L, nargs, nresults, errfunc);
    if (needClean)
        hook_leave(g);
#else
    lu_byte oldah = L->allowhook;
    L->allowhook = 0;
    int ok = lua_pcall(L, nargs, nresults, errfunc);
    L->allowhook = oldah;
#endif

    return ok;
}

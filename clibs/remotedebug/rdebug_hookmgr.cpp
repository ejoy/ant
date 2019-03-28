#include <lua.hpp>
#include <lstate.h>
#include <assert.h>
#include <stdint.h>
#include <new>
#include <memory>
#include "rdebug_eventfree.h"

static int HOOK_MGR = 0;
static int HOOK_CALLBACK = 0;

extern "C" {
lua_State* get_host(lua_State *L);
void set_host(lua_State* L, lua_State* hL);
lua_State* getthread(lua_State *L);
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
    if (!ttisLclosure(func)) {
        return 0;
    }
    return clLvalue(func)->p;
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
    void break_hook(lua_State* hL, lua_Debug* ar) {
        if (!break_mask) {
            return;
        }
        switch (ar->event) {
        case LUA_HOOKCALL:
        case LUA_HOOKTAILCALL:
            break_update(hL, ar->i_ci, ar->event);
            return;
        case LUA_HOOKRET:
            break_update(hL, ar->i_ci->previous, ar->event);
            return;
        }
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
    void step_hook(lua_State* hL, lua_Debug* ar) {
        if (stepL != hL) {
            return;
        }
        switch (ar->event) {
        case LUA_HOOKCALL:
        case LUA_HOOKTAILCALL:
            step_current_level++;
            if (step_current_level > step_target_level) {
                step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
            }
            else {
                step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
            }
            return;
        case LUA_HOOKRET:
            step_current_level = stacklevel(hL, step_current_level) - 1;
            if (step_current_level > step_target_level) {
                step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET);
            }
            else {
                step_hookmask(hL, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE);
            }
            return;
        default:
            break;
        }
    }
    void step_hookmask(lua_State* hL, int mask) {
        if (step_mask != mask) {
            step_mask = mask;
            updatehookmask(hL);
        }
    }

    //
    // common
    //
    lua_State* cL = 0;
    std::unique_ptr<thunk> sc_hook;
    hookmgr(lua_State* L)
        : cL(L)
        , sc_hook(thunk_create_hook(
            reinterpret_cast<intptr_t>(this),
            reinterpret_cast<intptr_t>(&hook_callback)
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

    void hook(lua_State* hL, lua_Debug* ar) {
        step_hook(hL, ar);
        break_hook(hL, ar);
        if (ar->event == LUA_HOOKLINE) {
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
    }
    void updatehookmask(lua_State* hL) {
        lua_sethook(hL, (lua_Hook)sc_hook->data, break_mask | step_mask, 0);
    }
    void setcoroutine(lua_State* hL) {
        updatehookmask(hL);
    }
    
    lua_State* hostL = 0;
    void start(lua_State* hL) {
        hostL = hL;
        thunk_bind((intptr_t)hL, (intptr_t)this);
        remotedebug::eventfree::create(hL, lua_freef, this);
    }
    ~hookmgr() {
        if(hostL) {
            remotedebug::eventfree::destroy(hostL);
        }
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
};

static int sethook(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    lua_settop(L, 1);
    hookmgr::get_self(L)->start(get_host(L));
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
        { "sethook", sethook },
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
        { NULL, NULL },
    };
    luaL_setfuncs(L, lib, 1);
    return 1;
}

extern "C"
void probe(lua_State* cL, lua_State* hL, const char* name) {
    if (LUA_TUSERDATA != lua_rawgetp(cL, LUA_REGISTRYINDEX, &HOOK_MGR)) {
        lua_pop(cL,1);
        return;
    }
    ((hookmgr*)lua_touserdata(cL,-1))->probe(hL, name);
    lua_pop(cL,1);
}

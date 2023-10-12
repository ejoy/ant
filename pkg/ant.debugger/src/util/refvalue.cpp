#include "util/refvalue.h"

#include <bee/nonstd/unreachable.h>

#include <cassert>
#include <cstring>

#include "compat/table.h"
#include "rdebug_lua.h"

namespace luadebug::refvalue {
    template <typename T>
    int eval(T&, lua_State*, value*);

    template <>
    int eval<FRAME_LOCAL>(FRAME_LOCAL& v, lua_State* hL, value*) {
        lua_Debug ar;
        if (lua_getstack(hL, v.frame, &ar) == 0)
            return LUA_TNONE;
        const char* name = lua_getlocal(hL, &ar, v.n);
        if (name) {
            return lua_type(hL, -1);
        }
        return LUA_TNONE;
    }

    template <>
    int eval<FRAME_FUNC>(FRAME_FUNC& v, lua_State* hL, value*) {
        lua_Debug ar;
        if (lua_getstack(hL, v.frame, &ar) == 0)
            return LUA_TNONE;
        if (lua_getinfo(hL, "f", &ar) == 0)
            return LUA_TNONE;
        return LUA_TFUNCTION;
    }

    template <>
    int eval<GLOBAL>(GLOBAL& v, lua_State* hL, value*) {
#if LUA_VERSION_NUM == 501
        lua_pushvalue(hL, LUA_GLOBALSINDEX);
        return LUA_TTABLE;
#else
        return lua::rawgeti(hL, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
#endif
    }

    template <>
    int eval<REGISTRY>(REGISTRY& v, lua_State* hL, value*) {
        switch (v.type) {
        case REGISTRY_TYPE::REGISTRY:
            lua_pushvalue(hL, LUA_REGISTRYINDEX);
            return LUA_TTABLE;
        case REGISTRY_TYPE::DEBUG_REF:
            return lua::getfield(hL, LUA_REGISTRYINDEX, "__debugger_ref");
        case REGISTRY_TYPE::DEBUG_WATCH:
            return lua::getfield(hL, LUA_REGISTRYINDEX, "__debugger_watch");
        default:
            std::unreachable();
        }
    }

    template <>
    int eval<STACK>(STACK& v, lua_State* hL, value*) {
        lua_pushvalue(hL, v.index);
        return lua_type(hL, -1);
    }

    template <>
    int eval<UPVALUE>(UPVALUE& v, lua_State* hL, value* parent) {
        int t = eval(parent, hL);
        if (t == LUA_TNONE)
            return LUA_TNONE;
        if (t != LUA_TFUNCTION) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        if (lua_getupvalue(hL, -1, v.n)) {
            lua_replace(hL, -2);
            return lua_type(hL, -1);
        }
        else {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
    }

    template <>
    int eval<METATABLE>(METATABLE& v, lua_State* hL, value* parent) {
        switch (v.type) {
        case LUA_TNIL:
            lua_pushnil(hL);
            break;
        case LUA_TBOOLEAN:
            lua_pushboolean(hL, 0);
            break;
        case LUA_TNUMBER:
            lua_pushinteger(hL, 0);
            break;
        case LUA_TSTRING:
            lua_pushstring(hL, "");
            break;
        case LUA_TLIGHTUSERDATA:
            lua_pushlightuserdata(hL, NULL);
            break;
        case LUA_TTABLE:
        case LUA_TUSERDATA: {
            int t = eval(parent, hL);
            if (t == LUA_TNONE)
                return LUA_TNONE;
            if (t != LUA_TTABLE && t != LUA_TUSERDATA) {
                lua_pop(hL, 1);
                return LUA_TNONE;
            }
            break;
        }
        default:
            return LUA_TNONE;
        }
        if (lua_getmetatable(hL, -1)) {
            lua_replace(hL, -2);
            return lua_type(hL, -1);
        }
        else {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
    }

    template <>
    int eval<USERVALUE>(USERVALUE& v, lua_State* hL, value* parent) {
        int t = eval(parent, hL);
        if (t == LUA_TNONE)
            return LUA_TNONE;
        if (t != LUA_TUSERDATA) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        t = lua_getiuservalue(hL, -1, v.n);
        lua_replace(hL, -2);
        return t;
    }

    template <>
    int eval<TABLE_ARRAY>(TABLE_ARRAY& v, lua_State* hL, value* parent) {
        int t = eval(parent, hL);
        if (t == LUA_TNONE)
            return LUA_TNONE;
        if (t != LUA_TTABLE) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        const void* tv = lua_topointer(hL, -1);
        if (!tv) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        if (!luadebug::table::get_array(hL, tv, v.index)) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        lua_replace(hL, -2);
        return lua_type(hL, -1);
    }

    template <>
    int eval<TABLE_HASH_KEY>(TABLE_HASH_KEY& v, lua_State* hL, value* parent) {
        int t = eval(parent, hL);
        if (t == LUA_TNONE)
            return LUA_TNONE;
        if (t != LUA_TTABLE) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        const void* tv = lua_topointer(hL, -1);
        if (!tv) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        if (!luadebug::table::get_hash_k(hL, tv, v.index)) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        lua_replace(hL, -2);
        return lua_type(hL, -1);
    }

    template <>
    int eval<TABLE_HASH_VAL>(TABLE_HASH_VAL& v, lua_State* hL, value* parent) {
        int t = eval(parent, hL);
        if (t == LUA_TNONE)
            return LUA_TNONE;
        if (t != LUA_TTABLE) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        const void* tv = lua_topointer(hL, -1);
        if (!tv) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        if (!luadebug::table::get_hash_v(hL, tv, v.index)) {
            lua_pop(hL, 1);
            return LUA_TNONE;
        }
        lua_replace(hL, -2);
        return lua_type(hL, -1);
    }

    int eval(value* v, lua_State* hL) {
        return visit([hL, v](auto&& arg) { return eval(arg, hL, v + 1); }, *v);
    }

    template <typename T>
    bool assign(T&, lua_State*, value*) {
        return false;
    }

    template <>
    bool assign<FRAME_LOCAL>(FRAME_LOCAL& v, lua_State* hL, value*) {
        lua_Debug ar;
        if (lua_getstack(hL, v.frame, &ar) == 0) {
            return false;
        }
        if (lua_setlocal(hL, &ar, v.n) != NULL) {
            return true;
        }
        return false;
    }

    template <>
    bool assign<UPVALUE>(UPVALUE& v, lua_State* hL, value* parent) {
        int t = eval(parent, hL);
        if (t != LUA_TFUNCTION)
            return false;
        lua_insert(hL, -2);
        return lua_setupvalue(hL, -2, v.n) != NULL;
    }

    template <>
    bool assign<METATABLE>(METATABLE& v, lua_State* hL, value* parent) {
        switch (v.type) {
        case LUA_TNIL:
            lua_pushnil(hL);
            break;
        case LUA_TBOOLEAN:
            lua_pushboolean(hL, 0);
            break;
        case LUA_TNUMBER:
            lua_pushinteger(hL, 0);
            break;
        case LUA_TSTRING:
            lua_pushstring(hL, "");
            break;
        case LUA_TLIGHTUSERDATA:
            lua_pushlightuserdata(hL, NULL);
            break;
        case LUA_TTABLE:
        case LUA_TUSERDATA: {
            int t = eval(parent, hL);
            if (t != LUA_TTABLE && t != LUA_TUSERDATA) {
                return false;
            }
            break;
        }
        default:
            return false;
        }

        lua_insert(hL, -2);
        int metattype = lua_type(hL, -1);
        if (metattype != LUA_TNIL && metattype != LUA_TTABLE) {
            return false;
        }
        lua_setmetatable(hL, -2);
        return true;
    }

    template <>
    bool assign<USERVALUE>(USERVALUE& v, lua_State* hL, value* parent) {
        int t = eval(parent, hL);
        if (t != LUA_TUSERDATA)
            return false;
        lua_insert(hL, -2);
        lua_setiuservalue(hL, -2, v.n);
        return true;
    }

    template <>
    bool assign<TABLE_ARRAY>(TABLE_ARRAY& v, lua_State* hL, value* parent) {
        int t = eval(parent, hL);
        if (t != LUA_TTABLE)
            return false;
        lua_insert(hL, -2);
        const void* tv = lua_topointer(hL, -2);
        if (!tv)
            return false;
        return luadebug::table::set_array(hL, tv, v.index);
    }

    template <>
    bool assign<TABLE_HASH_VAL>(TABLE_HASH_VAL& v, lua_State* hL, value* parent) {
        int t = eval(parent, hL);
        if (t == LUA_TNONE)
            return false;
        if (t != LUA_TTABLE)
            return false;
        lua_insert(hL, -2);
        const void* tv = lua_topointer(hL, -2);
        if (!tv)
            return false;
        return luadebug::table::set_hash_v(hL, tv, v.index);
    }

    bool assign(value* v, lua_State* hL) {
        int top = lua_gettop(hL);
        bool ok = visit([hL, v](auto&& arg) { return assign(arg, hL, v + 1); }, *v);
        lua_settop(hL, top - 2);
        return ok;
    }

    value* create_userdata(luadbg_State* L, int n) {
        return (value*)luadbg_newuserdatauv(L, n * sizeof(value), 0);
    }

    value* create_userdata(luadbg_State* L, int n, int parent) {
        assert(luadbg_type(L, parent) == LUADBG_TUSERDATA);
        void* parent_data  = luadbg_touserdata(L, parent);
        size_t parent_size = static_cast<size_t>(luadbg_rawlen(L, parent));
        void* v            = luadbg_newuserdatauv(L, n * sizeof(value) + parent_size, 0);
        memcpy((std::byte*)v + n * sizeof(value), parent_data, parent_size);
        return (value*)v;
    }
}

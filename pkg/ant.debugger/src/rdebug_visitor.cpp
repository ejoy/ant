#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <algorithm>
#include <bitset>
#include <limits>

#include "compat/internal.h"
#include "compat/table.h"
#include "rdebug_debughost.h"
#include "rdebug_lua.h"
#include "symbolize/symbolize.h"
#include "util/protected_area.h"
#include "util/refvalue.h"

#ifdef LUAJIT_VERSION
#    include <lj_cdata.h>
#    include <lj_debug.h>
#else
#    include <lstate.h>
#endif

namespace luadebug::visitor {
    static int debug_pcall(lua_State* hL, int nargs, int nresults, int errfunc) {
#ifdef LUAJIT_VERSION
        global_State* g = G(hL);
        bool needClean  = !hook_active(g);
        hook_enter(g);
        int ok = lua_pcall(hL, nargs, nresults, errfunc);
        if (needClean)
            hook_leave(g);
#else
        lu_byte oldah = hL->allowhook;
        hL->allowhook = 0;
        int ok        = lua_pcall(hL, nargs, nresults, errfunc);
        hL->allowhook = oldah;
#endif

        return ok;
    }

    static int copy_to_dbg(lua_State* hL, luadbg_State* L, int idx = -1) {
        int t = lua_type(hL, idx);
        switch (t) {
        case LUA_TNIL:
            luadbg_pushnil(L);
            break;
        case LUA_TBOOLEAN:
            luadbg_pushboolean(L, lua_toboolean(hL, idx));
            break;
        case LUA_TNUMBER:
#if LUA_VERSION_NUM >= 503 || defined(LUAJIT_VERSION)
            if (lua_isinteger(hL, idx)) {
                luadbg_pushinteger(L, lua_tointeger(hL, idx));
            }
            else {
                luadbg_pushnumber(L, lua_tonumber(hL, idx));
            }
#else
            luadbg_pushnumber(L, lua_tonumber(hL, idx));
#endif
            break;
        case LUA_TSTRING: {
            size_t sz;
            const char* str = lua_tolstring(hL, idx, &sz);
            luadbg_pushlstring(L, str, sz);
            break;
        }
        case LUA_TLIGHTUSERDATA:
            luadbg_pushlightuserdata(L, lua_touserdata(hL, idx));
            break;
        default:
            return LUA_TNONE;
        }
        return t;
    }

    static int copy_from_dbg(luadbg_State* L, lua_State* hL, protected_area& area, int idx) {
        area.check_client_stack(1);
        int t = luadbg_type(L, idx);
        switch (t) {
        case LUADBG_TNIL:
            lua_pushnil(hL);
            break;
        case LUADBG_TBOOLEAN:
            lua_pushboolean(hL, luadbg_toboolean(L, idx));
            break;
        case LUADBG_TNUMBER:
            if (luadbg_isinteger(L, idx)) {
                lua_pushinteger(hL, (lua_Integer)luadbg_tointeger(L, idx));
            }
            else {
                lua_pushnumber(hL, (lua_Number)luadbg_tonumber(L, idx));
            }
            break;
        case LUADBG_TSTRING: {
            size_t sz;
            const char* str = luadbg_tolstring(L, idx, &sz);
            lua_pushlstring(hL, str, sz);
            break;
        }
        case LUADBG_TLIGHTUSERDATA:
            lua_pushlightuserdata(hL, luadbg_touserdata(L, idx));
            break;
        case LUADBG_TUSERDATA: {
            area.check_client_stack(3);
            refvalue::value* v = (refvalue::value*)luadbg_touserdata(L, idx);
            return refvalue::eval(v, hL);
        }
        default:
            return LUADBG_TNONE;
        }
        return t;
    }

    static bool copy_from_dbg(luadbg_State* L, lua_State* hL, protected_area& area, int idx, int type) {
        int t = copy_from_dbg(L, hL, area, idx);
        if (t == type) {
            return true;
        }
        if (t != LUADBG_TNONE) {
            lua_pop(hL, 1);
        }
        return false;
    }

    static void copy_from_dbg_clonetable(luadbg_State* L, lua_State* hL, protected_area& area, int idx) {
        if (copy_from_dbg(L, hL, area, idx) == LUADBG_TNONE) {
            if (luadbg_type(L, idx) == LUADBG_TTABLE) {
                idx = luadbg_absindex(L, idx);
                area.check_client_stack(3);
                lua_newtable(hL);
                luadbg_pushnil(L);
                while (luadbg_next(L, idx)) {
                    copy_from_dbg_clonetable(L, hL, area, -2);
                    copy_from_dbg_clonetable(L, hL, area, -1);
                    lua_rawset(hL, -3);
                    luadbg_pop(L, 1);
                }
            }
            else {
                lua_pushnil(hL);
            }
        }
    }

    static void registry_table(lua_State* hL, refvalue::REGISTRY_TYPE type) {
        switch (type) {
        case refvalue::REGISTRY_TYPE::REGISTRY:
            lua_pushvalue(hL, LUA_REGISTRYINDEX);
            break;
        case refvalue::REGISTRY_TYPE::DEBUG_REF:
            if (lua::getfield(hL, LUA_REGISTRYINDEX, "__debugger_ref") == LUA_TNIL) {
                lua_pop(hL, 1);
                lua_newtable(hL);
                lua_pushvalue(hL, -1);
                lua_setfield(hL, LUA_REGISTRYINDEX, "__debugger_ref");
            }
            break;
        case refvalue::REGISTRY_TYPE::DEBUG_WATCH:
            if (lua::getfield(hL, LUA_REGISTRYINDEX, "__debugger_watch") == LUA_TNIL) {
                lua_pop(hL, 1);
                lua_newtable(hL);
                lua_pushvalue(hL, -1);
                lua_setfield(hL, LUA_REGISTRYINDEX, "__debugger_watch");
            }
            break;
        default:
            std::unreachable();
        }
    }

    static int registry_ref(luadbg_State* L, lua_State* hL, refvalue::REGISTRY_TYPE type) {
        int ref = luaL_ref(hL, -2);
        if (ref <= 0) {
            luadbg_pushnil(L);
            return LUA_NOREF;
        }
        unsigned int index = table::array_base_zero() ? (unsigned int)(ref) : (unsigned int)(ref - 1);
        const void* tv     = lua_topointer(hL, -1);
        if (!tv || index >= table::array_size(tv)) {
            luadbg_pushnil(L);
            return LUA_NOREF;
        }
        refvalue::create(L, refvalue::TABLE_ARRAY { index }, refvalue::REGISTRY { type });
        return ref;
    }

    void registry_unref(lua_State* hL, int ref) {
        if (ref >= 0) {
            if (lua::getfield(hL, LUA_REGISTRYINDEX, "__debugger_ref") == LUA_TTABLE) {
                luaL_unref(hL, -1, ref);
            }
            lua_pop(hL, 1);
        }
    }

    int copy_to_dbg_ref(lua_State* hL, luadbg_State* L) {
        if (copy_to_dbg(hL, L) != LUA_TNONE) {
            return LUA_NOREF;
        }
        registry_table(hL, refvalue::REGISTRY_TYPE::DEBUG_REF);
        lua_pushvalue(hL, -2);
        int ref = registry_ref(L, hL, refvalue::REGISTRY_TYPE::DEBUG_REF);
        lua_pop(hL, 1);
        return ref;
    }

    template <bool getref = true>
    static int visitor_getlocal(luadbg_State* L, lua_State* hL, protected_area& area) {
        auto frame = area.checkinteger<uint16_t>(L, 1);
        auto n     = area.checkinteger<int16_t>(L, 2);
        lua_Debug ar;
        if (lua_getstack(hL, frame, &ar) == 0) {
            return 0;
        }
        area.check_client_stack(1);
        const char* name = lua::lua_getlocal(hL, &ar, n);
        if (name == NULL)
            return 0;
        if (!getref && copy_to_dbg(hL, L) != LUA_TNONE) {
            lua_pop(hL, 1);
            luadbg_pushstring(L, name);
            luadbg_insert(L, -2);
            return 2;
        }
        lua_pop(hL, 1);
        luadbg_pushstring(L, name);
        refvalue::create(L, refvalue::FRAME_LOCAL { frame, n });
        return 2;
    }

    template <bool getref = true>
    static int visitor_field(luadbg_State* L, lua_State* hL, protected_area& area) {
        auto field = area.checkstring(L, 2);
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TTABLE)) {
            return 0;
        }
        area.check_client_stack(1);
        lua_pushlstring(hL, field.data(), field.size());
        lua_rawget(hL, -2);
        if (!getref && copy_to_dbg(hL, L) != LUA_TNONE) {
            lua_pop(hL, 2);
            return 1;
        }
        lua_pop(hL, 1);
        const void* tv = lua_topointer(hL, -1);
        if (!tv) {
            lua_pop(hL, 1);
            return 0;
        }
        //
        // 使用简单的O(n)算法查找field，可以更好地保证兼容性。
        // field目前只在很少的场景使用，所以不用在意性能。
        //
        lua_pushlstring(hL, field.data(), field.size());
        lua_insert(hL, -2);
        unsigned int hsize = table::hash_size(tv);
        for (unsigned int i = 0; i < hsize; ++i) {
            if (table::get_hash_k(hL, tv, i)) {
                if (lua_rawequal(hL, -1, -3)) {
                    refvalue::create(L, 1, refvalue::TABLE_HASH_VAL { i });
                    lua_pop(hL, 3);
                    return 1;
                }
                lua_pop(hL, 1);
            }
        }
        lua_pop(hL, 2);
        return 0;
    }

    template <bool getref = true>
    static int visitor_tablearray(luadbg_State* L, lua_State* hL, protected_area& area) {
        unsigned int i = area.optinteger<unsigned int>(L, 2, 0);
        unsigned int j = area.optinteger<unsigned int>(L, 3, (std::numeric_limits<unsigned int>::max)());
        area.check_client_stack(4);
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TTABLE)) {
            return 0;
        }
        const void* tv = lua_topointer(hL, -1);
        if (!tv) {
            lua_pop(hL, 1);
            return 0;
        }
        luadbg_newtable(L);
        luadbg_Integer n  = 0;
        unsigned int maxn = table::array_size(tv);
        if (maxn == 0) {
            lua_pop(hL, 1);
            return 1;
        }
        j = (std::min)(j, maxn - 1);
        for (; i <= j; ++i) {
            bool ok = table::get_array(hL, tv, i);
            (void)ok;
            assert(ok);
            if (getref) {
                refvalue::create(L, 1, refvalue::TABLE_ARRAY { i });
                if (copy_to_dbg(hL, L) == LUA_TNONE) {
                    luadbg_pushvalue(L, -1);
                }
                luadbg_rawseti(L, -3, ++n);
            }
            else {
                if (copy_to_dbg(hL, L) == LUA_TNONE) {
                    refvalue::create(L, 1, refvalue::TABLE_ARRAY { i });
                }
            }
            luadbg_rawseti(L, -2, ++n);
            lua_pop(hL, 1);
        }
        lua_pop(hL, 1);
        return 1;
    }

    template <bool getref = true>
    static int visitor_tablehash(luadbg_State* L, lua_State* hL, protected_area& area) {
        unsigned int i = area.optinteger<unsigned int>(L, 2, 0);
        unsigned int j = area.optinteger<unsigned int>(L, 3, (std::numeric_limits<unsigned int>::max)());
        area.check_client_stack(4);
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TTABLE)) {
            return 0;
        }
        const void* tv = lua_topointer(hL, -1);
        if (!tv) {
            lua_pop(hL, 1);
            return 0;
        }
        luadbg_newtable(L);
        luadbg_Integer n  = 0;
        unsigned int maxn = table::hash_size(tv);
        if (maxn == 0) {
            lua_pop(hL, 1);
            return 1;
        }
        j = (std::min)(j, maxn - 1);
        for (; i <= j; ++i) {
            if (table::get_hash_kv(hL, tv, i)) {
                if (copy_to_dbg(hL, L) == LUA_TNONE) {
                    refvalue::create(L, 1, refvalue::TABLE_HASH_KEY { i });
                }
                luadbg_rawseti(L, -2, ++n);
                lua_pop(hL, 1);

                if (getref) {
                    refvalue::create(L, 1, refvalue::TABLE_HASH_VAL { i });
                    if (copy_to_dbg(hL, L) == LUA_TNONE) {
                        luadbg_pushvalue(L, -1);
                    }
                    luadbg_rawseti(L, -3, ++n);
                }
                else {
                    if (copy_to_dbg(hL, L) == LUA_TNONE) {
                        refvalue::create(L, 1, refvalue::TABLE_HASH_VAL { i });
                    }
                }
                luadbg_rawseti(L, -2, ++n);
                lua_pop(hL, 1);
            }
        }
        lua_pop(hL, 1);
        return 1;
    }

    static int visitor_tablesize(luadbg_State* L, lua_State* hL, protected_area& area) {
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TTABLE)) {
            return 0;
        }
        const void* t = lua_topointer(hL, -1);
        if (!t) {
            lua_pop(hL, 1);
            return 0;
        }
        luadbg_pushinteger(L, table::array_size(t));
        luadbg_pushinteger(L, table::hash_size(t));
        lua_pop(hL, 1);
        return 2;
    }

    static int visitor_udread(luadbg_State* L, lua_State* hL, protected_area& area) {
        auto offset = area.checkinteger<luadbg_Integer>(L, 2);
        auto count  = area.checkinteger<luadbg_Integer>(L, 3);
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TUSERDATA)) {
            return 0;
        }
        const char* memory = (const char*)lua_touserdata(hL, -1);
        size_t len         = (size_t)lua_rawlen(hL, -1);
        if (offset < 0 || (size_t)offset >= len || count <= 0) {
            lua_pop(hL, 1);
            return 0;
        }
        if ((size_t)(offset + count) > len) {
            count = (luadbg_Integer)len - offset;
        }
        luadbg_pushlstring(L, memory + offset, (size_t)count);
        lua_pop(hL, 1);
        return 1;
    }

    static int visitor_udwrite(luadbg_State* L, lua_State* hL, protected_area& area) {
        auto offset      = area.checkinteger<luadbg_Integer>(L, 2);
        auto data        = area.checkstring(L, 3);
        int allowPartial = luadbg_toboolean(L, 4);
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TUSERDATA)) {
            return 0;
        }
        const char* memory = (const char*)lua_touserdata(hL, -1);
        size_t len         = (size_t)lua_rawlen(hL, -1);
        if (allowPartial) {
            if (offset < 0 || (size_t)offset >= len) {
                lua_pop(hL, 1);
                luadbg_pushinteger(L, 0);
                return 1;
            }
            size_t bytesWritten = (std::min)(data.size(), (size_t)(len - offset));
            memcpy((void*)(memory + offset), data.data(), bytesWritten);
            lua_pop(hL, 1);
            luadbg_pushinteger(L, bytesWritten);
            return 1;
        }
        else {
            if (offset < 0 || (size_t)offset + data.size() > len) {
                lua_pop(hL, 1);
                return 0;
            }
            memcpy((void*)(memory + offset), data.data(), data.size());
            lua_pop(hL, 1);
            luadbg_pushboolean(L, 1);
            return 1;
        }
    }

    static int visitor_value(luadbg_State* L, lua_State* hL, protected_area& area) {
        switch (luadbg_type(L, 1)) {
        case LUADBG_TNIL:
        case LUADBG_TBOOLEAN:
        case LUADBG_TNUMBER:
        case LUADBG_TSTRING:
        case LUADBG_TLIGHTUSERDATA:
            luadbg_settop(L, 1);
            return 1;
        default:
            luadbg_pushnil(L);
            return 1;
        case LUADBG_TUSERDATA:
            break;
        }
        area.check_client_stack(3);
        refvalue::value* v = (refvalue::value*)luadbg_touserdata(L, 1);
        if (refvalue::eval(v, hL) == LUA_TNONE) {
            luadbg_pushnil(L);
            return 1;
        }
        if (copy_to_dbg(hL, L) == LUA_TNONE) {
            luadbg_pushfstring(L, "%s: %p", lua_typename(hL, lua_type(hL, -1)), lua_topointer(hL, -1));
        }
        lua_pop(hL, 1);
        return 1;
    }

    static int visitor_assign(luadbg_State* L, lua_State* hL, protected_area& area) {
        area.check_type(L, 1, LUADBG_TUSERDATA);
        area.check_client_stack(3);
        if (copy_from_dbg(L, hL, area, 1) == LUADBG_TNONE) {
            return 0;
        }
        if (copy_from_dbg(L, hL, area, 2) == LUADBG_TNONE) {
            lua_pop(hL, 1);
            return 0;
        }
        refvalue::value* ref = (refvalue::value*)luadbg_touserdata(L, 1);
        luadbg_pushboolean(L, refvalue::assign(ref, hL));
        return 1;
    }

    static int visitor_type(luadbg_State* L, lua_State* hL, protected_area& area) {
        switch (luadbg_type(L, 1)) {
        case LUADBG_TNIL:
            luadbg_pushstring(L, "nil");
            return 1;
        case LUADBG_TBOOLEAN:
            luadbg_pushstring(L, "boolean");
            return 1;
        case LUADBG_TSTRING:
            luadbg_pushstring(L, "string");
            return 1;
        case LUADBG_TLIGHTUSERDATA:
            luadbg_pushstring(L, "lightuserdata");
            return 1;
        case LUADBG_TNUMBER:
#if LUA_VERSION_NUM >= 503 || defined(LUAJIT_VERSION)
            if (luadbg_isinteger(L, 1)) {
                luadbg_pushstring(L, "integer");
            }
            else {
                luadbg_pushstring(L, "float");
            }
#else
            luadbg_pushstring(L, "float");
#endif
            return 1;
        case LUADBG_TUSERDATA:
            break;
        default:
            luadbg_pushstring(L, "unexpected");
            return 1;
        }
        area.check_client_stack(3);
        refvalue::value* v = (refvalue::value*)luadbg_touserdata(L, 1);
        int t              = refvalue::eval(v, hL);
        switch (t) {
        case LUA_TNONE:
            luadbg_pushstring(L, "unknown");
            return 1;
        case LUA_TFUNCTION:
            if (lua_iscfunction(hL, -1)) {
                luadbg_pushstring(L, "c function");
            }
            else {
                luadbg_pushstring(L, "function");
            }
            break;
        case LUA_TNUMBER:
#if LUA_VERSION_NUM >= 503 || defined(LUAJIT_VERSION)
            if (lua_isinteger(hL, -1)) {
                luadbg_pushstring(L, "integer");
            }
            else {
                luadbg_pushstring(L, "float");
            }
#else
            luadbg_pushstring(L, "float");
#endif
            break;
        case LUA_TLIGHTUSERDATA:
            luadbg_pushstring(L, "lightuserdata");
            break;
#ifdef LUAJIT_VERSION
        case LUA_TCDATA:
            luadbg_pushstring(L, lua_cdatatype(hL, -1));
            break;
#endif
        default:
            luadbg_pushstring(L, lua_typename(hL, t));
            break;
        }
        lua_pop(hL, 1);
        return 1;
    }

    template <bool getref = true>
    static int visitor_getupvalue(luadbg_State* L, lua_State* hL, protected_area& area) {
        auto index = area.checkinteger<int>(L, 2);
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TFUNCTION)) {
            return 0;
        }
        const char* name = lua_getupvalue(hL, -1, index);
        if (name == NULL) {
            lua_pop(hL, 1);
            return 0;
        }

        if (!getref && copy_to_dbg(hL, L) != LUA_TNONE) {
            lua_pop(hL, 2);
            luadbg_pushstring(L, name);
            luadbg_insert(L, -2);
            return 2;
        }
        lua_pop(hL, 2);
        luadbg_pushstring(L, name);
        refvalue::create(L, 1, refvalue::UPVALUE { index });
        return 2;
    }

    template <bool getref = true>
    static int visitor_getmetatable(luadbg_State* L, lua_State* hL, protected_area& area) {
        area.check_client_stack(2);
        int t = copy_from_dbg(L, hL, area, 1);
        if (t == LUADBG_TNONE) {
            return 0;
        }
        if (!getref) {
            if (lua_getmetatable(hL, -1) == 0) {
                lua_pop(hL, 1);
                return 0;
            }
            lua_pop(hL, 2);
        }
        else {
            lua_pop(hL, 1);
        }
        if (t == LUADBG_TTABLE || t == LUADBG_TUSERDATA) {
            refvalue::create(L, 1, refvalue::METATABLE { t });
            return 1;
        }
        else {
            luadbg_pop(L, 1);
            refvalue::create(L, refvalue::METATABLE { t });
            return 1;
        }
    }

    template <bool getref = true>
    static int visitor_getuservalue(luadbg_State* L, lua_State* hL, protected_area& area) {
        int n = area.optinteger<int>(L, 2, 1);
        area.check_client_stack(2);
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TUSERDATA)) {
            return 0;
        }
        if (!getref) {
            if (lua_getiuservalue(hL, -1, n) == LUA_TNONE) {
                lua_pop(hL, 2);
                return 0;
            }
            if (copy_to_dbg(hL, L) != LUA_TNONE) {
                lua_pop(hL, 2);
                luadbg_pushboolean(L, 1);
                return 2;
            }
            lua_pop(hL, 1);
        }
        lua_pop(hL, 1);
        refvalue::create(L, 1, refvalue::USERVALUE { n });
        luadbg_pushboolean(L, 1);
        return 2;
    }

    static int visitor_getinfo(luadbg_State* L, lua_State* hL, protected_area& area) {
        auto options = area.checkstring(L, 2);
        if (luadbg_type(L, 3) != LUA_TTABLE) {
            luadbg_createtable(L, 0, 16);
            luadbg_replace(L, 3);
        }

        std::bitset<128> flags;
        for (const char* what = options.data(); *what; what++) {
            flags.set(uint8_t(*what) & 0x7F, true);
        }

        lua_Debug ar;
        int frame = 0;
#if LUA_VERSION_NUM == 501
        uint8_t nparams = 0;
#endif

        switch (luadbg_type(L, 1)) {
        case LUADBG_TNUMBER:
            frame = area.checkinteger<int>(L, 1);
            if (lua_getstack(hL, frame, &ar) == 0)
                return 0;
            if (lua_getinfo(hL, options.data(), &ar) == 0)
                return 0;
#if LUA_VERSION_NUM == 501
            if (flags.test('u')) {
                Proto* proto = lua_ci2proto(lua_debug2ci(hL, &ar));
                if (proto) {
                    nparams = proto->numparams;
                }
            }
#endif
            if (flags.test('f')) lua_pop(hL, 1);
            break;
        case LUADBG_TUSERDATA: {
            if (!copy_from_dbg(L, hL, area, 1, LUADBG_TFUNCTION)) {
                return area.raise_error("Need a function ref");
            }
            if (flags.test('f')) {
                return area.raise_error("invalid option");
            }
            char what[8];
            what[0] = '>';
            strcpy(what + 1, options.data());
#if LUA_VERSION_NUM == 501
            if (flags.test('u')) {
                Proto* proto = lua_getproto(hL, -1);
                if (proto) {
                    nparams = proto->numparams;
                }
            }
#endif
            if (lua_getinfo(hL, what, &ar) == 0) {
                return 0;
            }
            break;
        }
        default:
            return area.raise_error("Need stack level (integer) or function ref");
        }
#ifdef LUAJIT_VERSION
        if (flags.test('S') && strcmp(ar.what, "main") == 0) {
            // carzy bug,luajit is real linedefined in main file,but in lua it's zero
            // maybe fix it is a new bug
            ar.lastlinedefined = 0;
        }
#endif

        for (const char* what = options.data(); *what; what++) {
            switch (*what) {
            case 'S':
#if LUA_VERSION_NUM >= 504
                luadbg_pushlstring(L, ar.source, ar.srclen);
#else
                luadbg_pushstring(L, ar.source);
#endif
                luadbg_setfield(L, 3, "source");
                luadbg_pushstring(L, ar.short_src);
                luadbg_setfield(L, 3, "short_src");
                luadbg_pushinteger(L, ar.linedefined);
                luadbg_setfield(L, 3, "linedefined");
                luadbg_pushinteger(L, ar.lastlinedefined);
                luadbg_setfield(L, 3, "lastlinedefined");
                luadbg_pushstring(L, ar.what ? ar.what : "?");
                luadbg_setfield(L, 3, "what");
                break;
            case 'l':
                luadbg_pushinteger(L, ar.currentline);
                luadbg_setfield(L, 3, "currentline");
                break;
            case 'n':
                luadbg_pushstring(L, ar.name ? ar.name : "?");
                luadbg_setfield(L, 3, "name");
                if (ar.namewhat) {
                    luadbg_pushstring(L, ar.namewhat);
                    luadbg_setfield(L, 3, "namewhat");
                }
                break;
            case 'f':
                refvalue::create(L, refvalue::FRAME_FUNC { (uint16_t)frame });
                luadbg_setfield(L, 3, "func");
                break;
            case 'u':
#if LUA_VERSION_NUM == 501
                luadbg_pushinteger(L, nparams);
#else
                luadbg_pushinteger(L, ar.nparams);
#endif
                luadbg_setfield(L, 3, "nparams");
                break;
#if LUA_VERSION_NUM >= 502
            case 't':
                luadbg_pushboolean(L, ar.istailcall ? 1 : 0);
                luadbg_setfield(L, 3, "istailcall");
                break;
#endif
#if LUA_VERSION_NUM >= 504
            case 'r':
                luadbg_pushinteger(L, ar.ftransfer);
                luadbg_setfield(L, 3, "ftransfer");
                luadbg_pushinteger(L, ar.ntransfer);
                luadbg_setfield(L, 3, "ntransfer");
                break;
#endif
            }
        }

        return 1;
    }

    static int visitor_load(luadbg_State* L, lua_State* hL, protected_area& area) {
        auto func = area.checkstring(L, 1);
        if (luaL_loadbuffer(hL, func.data(), func.size(), "=")) {
            luadbg_pushnil(L);
            luadbg_pushstring(L, lua_tostring(hL, -1));
            lua_pop(hL, 2);
            return 2;
        }
        copy_to_dbg_ref(hL, L);
        lua_pop(hL, 1);
        return 1;
    }

    static int visitor_eval(luadbg_State* L, lua_State* hL, protected_area& area) {
        int nargs = luadbg_gettop(L);
        area.check_client_stack(nargs);
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TFUNCTION)) {
            return 0;
        }
        for (int i = 2; i <= nargs; ++i) {
            copy_from_dbg_clonetable(L, hL, area, i);
        }
        if (debug_pcall(hL, nargs - 1, 1, 0)) {
            luadbg_pushboolean(L, 0);
            luadbg_pushstring(L, lua_tostring(hL, -1));
            lua_pop(hL, 1);
            return 2;
        }
        luadbg_pushboolean(L, 1);
        if (copy_to_dbg(hL, L) == LUA_TNONE) {
            luadbg_pushfstring(L, "%s: %p", lua_typename(hL, lua_type(hL, -1)), lua_topointer(hL, -1));
        }
        lua_pop(hL, 1);
        return 2;
    }

    static int visitor_watch(luadbg_State* L, lua_State* hL, protected_area& area) {
        int n     = lua_gettop(hL);
        int nargs = luadbg_gettop(L);
        area.check_client_stack(nargs);
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TFUNCTION)) {
            return 0;
        }
        for (int i = 2; i <= nargs; ++i) {
            copy_from_dbg_clonetable(L, hL, area, i);
        }
        if (debug_pcall(hL, nargs - 1, LUA_MULTRET, 0)) {
            luadbg_pushboolean(L, 0);
            luadbg_pushstring(L, lua_tostring(hL, -1));
            lua_pop(hL, 1);
            return 2;
        }
        area.check_client_stack(3);
        luadbg_pushboolean(L, 1);
        int rets = lua_gettop(hL) - n;
        area.check_host_stack(rets);
        registry_table(hL, refvalue::REGISTRY_TYPE::DEBUG_WATCH);
        for (int i = 0; i < rets; ++i) {
            lua_pushvalue(hL, i - rets - 1);
            registry_ref(L, hL, refvalue::REGISTRY_TYPE::DEBUG_WATCH);
        }
        lua_settop(hL, n);
        return 1 + rets;
    }

    static int visitor_cleanwatch(luadbg_State* L, lua_State* hL, protected_area& area) {
        lua_pushnil(hL);
        lua_setfield(hL, LUA_REGISTRYINDEX, "__debugger_watch");
        return 0;
    }

    static const char* costatus(lua_State* hL, lua_State* co) {
        if (hL == co) return "running";
        switch (lua_status(co)) {
        case LUA_YIELD:
            return "suspended";
        case LUA_OK: {
            lua_Debug ar;
            if (lua_getstack(co, 0, &ar)) return "normal";
            if (lua_gettop(co) == 0) return "dead";
            return "suspended";
        }
        default:
            return "dead";
        }
    }

    static int visitor_costatus(luadbg_State* L, lua_State* hL, protected_area& area) {
        if (!copy_from_dbg(L, hL, area, 1, LUADBG_TTHREAD)) {
            luadbg_pushstring(L, "invalid");
            return 1;
        }
        const char* s = costatus(hL, lua_tothread(hL, -1));
        lua_pop(hL, 1);
        luadbg_pushstring(L, s);
        return 1;
    }

    static int visitor_gccount(luadbg_State* L, lua_State* hL, protected_area& area) {
        int k    = lua_gc(hL, LUA_GCCOUNT, 0);
        int b    = lua_gc(hL, LUA_GCCOUNTB, 0);
        size_t m = ((size_t)k << 10) & (size_t)b;
        luadbg_pushinteger(L, (luadbg_Integer)m);
        return 1;
    }

    static int visitor_cfunctioninfo(luadbg_State* L, lua_State* hL, protected_area& area) {
        if (copy_from_dbg(L, hL, area, 1) == LUADBG_TNONE) {
            return 0;
        }
        const void* cfn = lua_tocfunction_pointer(hL, -1);
        lua_pop(hL, 1);
        auto info = symbolize(cfn);
        luadbg_newtable(L);
        luadbg_pushfstring(L, "%p", cfn);
        luadbg_setfield(L, -2, "tostring");
        if (info.file_name) {
            luadbg_pushlstring(L, info.file_name->c_str(), info.file_name->size());
            luadbg_setfield(L, -2, "file_name");
        }
        if (info.function_name) {
            luadbg_pushlstring(L, info.function_name->c_str(), info.function_name->size());
            luadbg_setfield(L, -2, "function_name");
        }
        if (info.module_name) {
            luadbg_pushlstring(L, info.module_name->c_str(), info.module_name->size());
            luadbg_setfield(L, -2, "module_name");
        }
        if (info.line_number) {
            luadbg_pushlstring(L, info.line_number->c_str(), info.line_number->size());
            luadbg_setfield(L, -2, "line_number");
        }

        return 1;
    }

    static int luaopen(luadbg_State* L) {
        luadbgL_Reg l[] = {
            { "getlocal", protected_call<visitor_getlocal> },
            { "getlocalv", protected_call<visitor_getlocal<false>> },
            { "getupvalue", protected_call<visitor_getupvalue> },
            { "getupvaluev", protected_call<visitor_getupvalue<false>> },
            { "getmetatable", protected_call<visitor_getmetatable> },
            { "getmetatablev", protected_call<visitor_getmetatable<false>> },
            { "getuservalue", protected_call<visitor_getuservalue> },
            { "getuservaluev", protected_call<visitor_getuservalue<false>> },
            { "field", protected_call<visitor_field> },
            { "fieldv", protected_call<visitor_field<false>> },
            { "tablearray", protected_call<visitor_tablearray> },
            { "tablearrayv", protected_call<visitor_tablearray<false>> },
            { "tablehash", protected_call<visitor_tablehash> },
            { "tablehashv", protected_call<visitor_tablehash<false>> },
            { "tablesize", protected_call<visitor_tablesize> },
            { "udread", protected_call<visitor_udread> },
            { "udwrite", protected_call<visitor_udwrite> },
            { "value", protected_call<visitor_value> },
            { "assign", protected_call<visitor_assign> },
            { "type", protected_call<visitor_type> },
            { "getinfo", protected_call<visitor_getinfo> },
            { "load", protected_call<visitor_load> },
            { "eval", protected_call<visitor_eval> },
            { "watch", protected_call<visitor_watch> },
            { "cleanwatch", protected_call<visitor_cleanwatch> },
            { "costatus", protected_call<visitor_costatus> },
            { "gccount", protected_call<visitor_gccount> },
            { "cfunctioninfo", protected_call<visitor_cfunctioninfo> },
            { NULL, NULL },
        };
        debughost::get(L);
        luadbgL_newlibtable(L, l);
        luadbgL_setfuncs(L, l, 0);
        refvalue::create(L, refvalue::GLOBAL {});
        luadbg_setfield(L, -2, "_G");
        refvalue::create(L, refvalue::REGISTRY { refvalue::REGISTRY_TYPE::REGISTRY });
        luadbg_setfield(L, -2, "_REGISTRY");
        return 1;
    }
}

LUADEBUG_FUNC
int luaopen_luadebug_visitor(luadbg_State* L) {
    return luadebug::visitor::luaopen(L);
}

#include "rdebug_debughost.h"

#include <cstdlib>

#include "luadbg/bee_module.h"
#include "rdebug_lua.h"

#if defined(_WIN32)
#    include "rdebug_win32.h"
#    if !defined(LUADBG_DISABLE)
#        include <bee/win/unicode.h>
#    endif
#endif

static int DEBUG_HOST   = 0;
static int DEBUG_CLIENT = 0;

bool event(luadbg_State* L, lua_State* hL, const char* name, int start);

namespace luadebug::debughost {
    luadbg_State* get_client(lua_State* hL) {
        if (lua::rawgetp(hL, LUA_REGISTRYINDEX, &DEBUG_CLIENT) != LUA_TLIGHTUSERDATA) {
            lua_pop(hL, 1);
            return 0;
        }
        luadbg_State* L = (luadbg_State*)lua_touserdata(hL, -1);
        lua_pop(hL, 1);
        return L;
    }

    void set(luadbg_State* L, lua_State* hL) {
        luadbg_pushlightuserdata(L, hL);
        luadbg_rawsetp(L, LUADBG_REGISTRYINDEX, &DEBUG_HOST);
    }

    lua_State* get(luadbg_State* L) {
        if (luadbg_rawgetp(L, LUADBG_REGISTRYINDEX, &DEBUG_HOST) != LUA_TLIGHTUSERDATA) {
            luadbg_pushstring(L, "Must call in debug client");
            luadbg_error(L);
            return 0;
        }
        lua_State* hL = (lua_State*)luadbg_touserdata(L, -1);
        luadbg_pop(L, 1);
        return hL;
    }

    static void clear_client(lua_State* hL) {
        luadbg_State* L = get_client(hL);
        lua_pushnil(hL);
        lua_rawsetp(hL, LUA_REGISTRYINDEX, &DEBUG_CLIENT);
        if (L) {
            luadbg_close(L);
        }
    }

    static int clear(lua_State* hL) {
        luadbg_State* L = get_client(hL);
        if (L) {
            event(L, hL, "exit", 1);
        }
        clear_client(hL);
        return 0;
    }

    static int client_main(luadbg_State* L) {
        lua_State* hL = (lua_State*)luadbg_touserdata(L, 2);
        set(L, hL);
        luadbg_pushboolean(L, 1);
        luadbg_setfield(L, LUADBG_REGISTRYINDEX, "LUA_NOENV");
        luadbgL_openlibs(L);
        luadebug::require_all(L);

#if !defined(LUADBG_DISABLE) || LUA_VERSION_NUM >= 504
#    if !defined(LUA_GCGEN)
#        define LUA_GCGEN 10
#    endif
        luadbg_gc(L, LUA_GCGEN, 0, 0);
#endif
        const char* mainscript = (const char*)luadbg_touserdata(L, 1);
        if (luadbgL_loadstring(L, mainscript) != LUA_OK) {
            return luadbg_error(L);
        }
        luadbg_pushvalue(L, 3);
        luadbg_call(L, 1, 0);
        return 0;
    }

    static void push_errmsg(lua_State* hL, luadbg_State* L) {
        if (luadbg_type(L, -1) != LUA_TSTRING) {
            lua_pushstring(hL, "Unknown Error");
        }
        else {
            size_t sz       = 0;
            const char* err = luadbg_tolstring(L, -1, &sz);
            lua_pushlstring(hL, err, sz);
        }
    }

    static int start(lua_State* hL) {
        clear_client(hL);
        lua_CFunction preprocessor = NULL;
        const char* mainscript     = luaL_checkstring(hL, 1);
        if (lua_type(hL, 2) == LUA_TFUNCTION) {
            preprocessor = lua_tocfunction(hL, 2);
            if (preprocessor == NULL) {
                lua_pushstring(hL, "Preprocessor must be a C function");
                return lua_error(hL);
            }
            if (lua_getupvalue(hL, 2, 1)) {
                lua_pushstring(hL, "Preprocessor must be a light C function (no upvalue)");
                return lua_error(hL);
            }
        }
        luadbg_State* L = luadbgL_newstate();
        if (L == NULL) {
            lua_pushstring(hL, "Can't new debug client");
            return lua_error(hL);
        }

        lua_pushlightuserdata(hL, L);
        lua_rawsetp(hL, LUA_REGISTRYINDEX, &DEBUG_CLIENT);

        luadbg_pushcfunction(L, client_main);
        luadbg_pushlightuserdata(L, (void*)mainscript);
        luadbg_pushlightuserdata(L, (void*)hL);
        if (preprocessor) {
            // TODO: convert C function？
            luadbg_pushcfunction(L, (luadbg_CFunction)preprocessor);
        }
        else {
            luadbg_pushnil(L);
        }

        if (luadbg_pcall(L, 3, 0, 0) != LUA_OK) {
            push_errmsg(hL, L);
            clear_client(hL);
            return lua_error(hL);
        }
        return 0;
    }

    static int event(lua_State* hL) {
        luadbg_State* L = get_client(hL);
        if (!L) {
            return 0;
        }
        bool ok = event(L, hL, luaL_checkstring(hL, 1), 2);
        if (!ok) {
            return 0;
        }
        lua_pushboolean(hL, ok);
        return 1;
    }

#if defined(_WIN32) && !defined(LUADBG_DISABLE)
    static bee::zstring_view to_strview(lua_State* hL, int idx) {
        size_t len      = 0;
        const char* buf = luaL_checklstring(hL, idx, &len);
        return { buf, len };
    }

    static int a2u(lua_State* hL) {
        std::string r = bee::win::a2u(to_strview(hL, 1));
        lua_pushlstring(hL, r.data(), r.size());
        return 1;
    }
#endif

    static int setenv(lua_State* hL) {
        const char* name  = luaL_checkstring(hL, 1);
        const char* value = luaL_checkstring(hL, 2);
#if defined(_WIN32)
        lua_pushfstring(hL, "%s=%s", name, value);
        luadebug::win32::putenv(lua_tostring(hL, -1));
#else
        ::setenv(name, value, 1);
#endif
        return 0;
    }
    static int luaopen(lua_State* hL) {
        luaL_Reg l[] = {
            { "start", start },
            { "clear", clear },
            { "event", event },
            { "setenv", setenv },
#if defined(_WIN32) && !defined(LUADBG_DISABLE)
            { "a2u", a2u },
#endif
            { NULL, NULL },
        };
#if LUA_VERSION_NUM == 501
        lua_createtable(hL, 0, sizeof(l) / sizeof((l)[0]) - 1);
        luaL_register(hL, nullptr, l);
        lua_newuserdata(hL, 0);
#else
        luaL_newlibtable(hL, l);
        luaL_setfuncs(hL, l, 0);
#endif

        lua_createtable(hL, 0, 1);
        lua_pushcfunction(hL, clear);
        lua_setfield(hL, -2, "__gc");
        lua_setmetatable(hL, -2);

#if LUA_VERSION_NUM == 501
        lua_rawseti(hL, -2, 0);
#endif
        return 1;
    }

}

LUADEBUG_FUNC
int luaopen_luadebug(lua_State* hL) {
    return luadebug::debughost::luaopen(hL);
}

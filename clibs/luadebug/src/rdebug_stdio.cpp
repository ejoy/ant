#include <limits>
#include <new>

#include "rdebug_debughost.h"
#include "rdebug_lua.h"
#include "rdebug_redirect.h"

bool event(luadbg_State* L, lua_State* hL, const char* name, int start);

namespace luadebug::stdio {
    static int getIoOutput(lua_State* hL) {
#if LUA_VERSION_NUM >= 502
        return lua::getfield(hL, LUA_REGISTRYINDEX, "_IO_output");
#else
        return lua::rawgeti(hL, LUA_ENVIRONINDEX, 2);
#endif
    }

    static int redirect_read(luadbg_State* L) {
        std_redirect& self = *(std_redirect*)luadbgL_checkudata(L, 1, "redirect");
        luadbg_Integer len = luadbgL_optinteger(L, 2, LUAL_BUFFERSIZE);
        if (len > (std::numeric_limits<int>::max)()) {
            return luadbgL_error(L, "bad argument #1 to 'read' (invalid number)");
        }
        if (len <= 0) {
            return 0;
        }
        luadbgL_Buffer b;
        luadbgL_buffinit(L, &b);
        char* buf = luadbgL_prepbuffsize(&b, (size_t)len);
        size_t rc = self.read(buf, (size_t)len);
        if (rc == 0) {
            return 0;
        }
        luadbgL_pushresultsize(&b, rc);
        return 1;
    }

    static int redirect_peek(luadbg_State* L) {
#if defined(_WIN32)
        std_redirect& self = *(std_redirect*)luadbgL_checkudata(L, 1, "redirect");
        luadbg_pushinteger(L, self.peek());
#else
        luadbg_pushinteger(L, LUAL_BUFFERSIZE);
#endif
        return 1;
    }

    static int redirect_close(luadbg_State* L) {
        std_redirect& self = *(std_redirect*)luadbgL_checkudata(L, 1, "redirect");
        self.close();
        return 0;
    }

    static int redirect_gc(luadbg_State* L) {
        std_redirect& self = *(std_redirect*)luadbgL_checkudata(L, 1, "redirect");
        self.close();
        self.~std_redirect();
        return 0;
    }

    static int redirect(luadbg_State* L) {
        const char* lst[] = { "stdin", "stdout", "stderr", NULL };
        std_fd type       = (std_fd)(luadbgL_checkoption(L, 1, "stdout", lst));
        switch (type) {
        case std_fd::STDIN:
        case std_fd::STDOUT:
        case std_fd::STDERR:
            break;
        default:
            return 0;
        }
        std_redirect* r = (std_redirect*)luadbg_newuserdata(L, sizeof(std_redirect));
        new (r) std_redirect;
        if (!r->open(type)) {
            return 0;
        }
        if (luadbgL_newmetatable(L, "redirect")) {
            static luadbgL_Reg mt[] = {
                { "read", redirect_read },
                { "peek", redirect_peek },
                { "close", redirect_close },
                { "__gc", redirect_gc },
                { NULL, NULL }
            };
            luadbgL_setfuncs(L, mt, 0);
            luadbg_pushvalue(L, -1);
            luadbg_setfield(L, -2, "__index");
        }
        luadbg_setmetatable(L, -2);
        return 1;
    }

    static int callfunc(lua_State* hL) {
        lua_pushvalue(hL, lua_upvalueindex(1));
        lua_insert(hL, 1);
        lua_call(hL, lua_gettop(hL) - 1, LUA_MULTRET);
        return lua_gettop(hL);
    }

    static int redirect_print(lua_State* hL) {
        luadbg_State* L = debughost::get_client(hL);
        if (L) {
            bool ok = event(L, hL, "print", 1);
            if (ok) {
                return 0;
            }
        }
        return callfunc(hL);
    }

    static int redirect_f_write(lua_State* hL) {
        bool ok = LUA_TUSERDATA == getIoOutput(hL) && lua_rawequal(hL, -1, 1);
        lua_pop(hL, 1);
        if (ok) {
            luadbg_State* L = debughost::get_client(hL);
            if (L) {
                bool ok = event(L, hL, "iowrite", 2);
                if (ok) {
                    lua_settop(hL, 1);
                    return 1;
                }
            }
        }
        return callfunc(hL);
    }

    static int redirect_io_write(lua_State* hL) {
        luadbg_State* L = debughost::get_client(hL);
        if (L) {
            bool ok = event(L, hL, "iowrite", 1);
            if (ok) {
                getIoOutput(hL);
                return 1;
            }
        }
        return callfunc(hL);
    }

    static bool openhook(lua_State* hL, bool enable, lua_CFunction f) {
        if (enable) {
            lua_pushcclosure(hL, f, 1);
            return true;
        }
        if (lua_tocfunction(hL, -1) == f) {
            if (lua_getupvalue(hL, -1, 1)) {
                lua_remove(hL, -2);
                return true;
            }
        }
        lua_pop(hL, 1);
        return false;
    }

    static int open_print(luadbg_State* L) {
        bool enable   = luadbg_toboolean(L, 1);
        lua_State* hL = debughost::get(L);
        lua_getglobal(hL, "print");
        if (openhook(hL, enable, redirect_print)) {
            lua_setglobal(hL, "print");
        }
        return 0;
    }

    static int open_iowrite(luadbg_State* L) {
        bool enable   = luadbg_toboolean(L, 1);
        lua_State* hL = debughost::get(L);
        if (LUA_TUSERDATA == getIoOutput(hL)) {
            if (lua_getmetatable(hL, -1)) {
#if LUA_VERSION_NUM >= 504
                lua_pushstring(hL, "__index");
                if (LUA_TTABLE == lua_rawget(hL, -2)) {
                    lua_remove(hL, -2);
#endif
                    lua_pushstring(hL, "write");
                    lua_pushvalue(hL, -1);
                    lua_rawget(hL, -3);
                    if (openhook(hL, enable, redirect_f_write)) {
                        lua_rawset(hL, -3);
                    }
                    lua_pop(hL, 1);
#if LUA_VERSION_NUM >= 504
                }
                else {
                    lua_pop(hL, 1);
                }
#endif
            }
        }
        lua_pop(hL, 1);
        if (LUA_TTABLE == lua::getglobal(hL, "io")) {
            lua_pushstring(hL, "write");
            lua_pushvalue(hL, -1);
            lua_rawget(hL, -3);
            if (openhook(hL, enable, redirect_io_write)) {
                lua_rawset(hL, -3);
            }
        }
        lua_pop(hL, 1);
        return 0;
    }

    static int luaopen(luadbg_State* L) {
        luadbg_newtable(L);
        static luadbgL_Reg lib[] = {
            { "redirect", redirect },
            { "open_print", open_print },
            { "open_iowrite", open_iowrite },
            { NULL, NULL },
        };
        luadbgL_setfuncs(L, lib, 0);
        return 1;
    }
}
LUADEBUG_FUNC
int luaopen_luadebug_stdio(luadbg_State* L) {
    return luadebug::stdio::luaopen(L);
}

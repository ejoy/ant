#include <lua.hpp>
#include <new>
#include <limits>
#include "rdebug_redirect.h"

lua_State* get_host(lua_State *L);
lua_State* get_client(lua_State *L);
int  event(lua_State* cL, lua_State* hL, const char* name);

static int redirect_read(lua_State* L) {
    remotedebug::redirect& self = *(remotedebug::redirect*)luaL_checkudata(L, 1, "redirect");
    lua_Integer len = luaL_optinteger(L, 2, LUAL_BUFFERSIZE);
    if (len > (std::numeric_limits<int>::max)()) {
        return luaL_error(L, "bad argument #1 to 'read' (invalid number)");
    }
    if (len <= 0) {
        return 0;
    }
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    char* buf = luaL_prepbuffsize(&b, (size_t)len);
    size_t rc = self.read(buf, (size_t)len);
    if (rc == 0) {
        return 0;
    }
    luaL_pushresultsize(&b, rc);
    return 1;
}

static int redirect_peek(lua_State* L) {
#if defined(_WIN32)
    remotedebug::redirect& self = *(remotedebug::redirect*)luaL_checkudata(L, 1, "redirect");
    lua_pushinteger(L, self.peek());
#else
    lua_pushinteger(L, LUAL_BUFFERSIZE);
#endif
    return 1;
}

static int redirect_close(lua_State* L) {
    remotedebug::redirect& self = *(remotedebug::redirect*)luaL_checkudata(L, 1, "redirect");
    self.close();
    return 0;
}

static int redirect_gc(lua_State* L) {
    remotedebug::redirect& self = *(remotedebug::redirect*)luaL_checkudata(L, 1, "redirect");
    self.close();
    self.~redirect();
    return 0;
}

static int redirect(lua_State* L) {
    const char* lst[] = {"stdin", "stdout", "stderr"};
    remotedebug::std_fd type = (remotedebug::std_fd)(luaL_checkoption(L, 1, "stdout", lst));
    switch (type) {
    case remotedebug::std_fd::STDIN:
    case remotedebug::std_fd::STDOUT:
    case remotedebug::std_fd::STDERR:
        break;
    default:
        return 0;
    }
    remotedebug::redirect* r = (remotedebug::redirect*)lua_newuserdata(L, sizeof(remotedebug::redirect));
    new (r) remotedebug::redirect;
    if (!r->open(type)) {
        return 0;
    }
    if (luaL_newmetatable(L, "redirect")) {
        static luaL_Reg mt[] = {
            { "read", redirect_read },
            { "peek", redirect_peek },
            { "close", redirect_close },
            { "__gc", redirect_gc },
            { NULL, NULL }
        };
        luaL_setfuncs(L, mt, 0);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
    return 1;
}

static int callfunc(lua_State* L) {
    lua_pushvalue(L, lua_upvalueindex(1));
    lua_insert(L, 1);
    lua_call(L, lua_gettop(L) - 1, LUA_MULTRET);
    return lua_gettop(L);
}

static int redirect_print(lua_State* L) {
	lua_State *cL = get_client(L);
    if (cL) {
        lua_pushnil(L);
        lua_insert(L, 1);
	    int ok = event(cL, L, "print");
        if (ok > 0) {
            return 0;
        }
    }
    return callfunc(L);
}

static int redirect_f_write(lua_State* L) {
	lua_State *cL = get_client(L);
    if (cL) {
        if (LUA_TUSERDATA == lua_getfield(L, LUA_REGISTRYINDEX, "_IO_output") && lua_rawequal(L, -1, 1)) {
            lua_pop(L, 1);
            int ok = event(cL, L, "iowrite");
            if (ok > 0) {
                lua_settop(L, 1);
                return 1;
            }
        }
        else {
            lua_pop(L, 1);
        }
    }
    return callfunc(L);
}

static int redirect_io_write(lua_State* L) {
	lua_State *cL = get_client(L);
    if (cL) {
        lua_pushnil(L);
        lua_insert(L, 1);
	    int ok = event(cL, L, "iowrite");
        if (ok > 0) {
            lua_getfield(L, LUA_REGISTRYINDEX, "_IO_output");
            return 1;
        }
    }
    return callfunc(L);
}

static int open_print(lua_State* L) {
    bool enable = lua_toboolean(L, 1);
    lua_State* hL = get_host(L);
    lua_getglobal(hL, "print");
    enable
        ? lua_pushcclosure(hL, redirect_print, 1)
        : (lua_getuservalue(hL, 1), lua_remove(hL, -2))
        ;
    lua_setglobal(hL, "print");
    return 0;
}

static int open_iowrite(lua_State* L) {
    bool enable = lua_toboolean(L, 1);
    lua_State* hL = get_host(L);
    if (LUA_TUSERDATA == lua_getfield(hL, LUA_REGISTRYINDEX, "_IO_output")) {
        if (lua_getmetatable(hL, -1)) {
            lua_pushstring(hL, "write");
            lua_pushvalue(hL, -1);
            lua_rawget(hL, -3);
            enable
                ? lua_pushcclosure(hL, redirect_f_write, 1)
                : (lua_getuservalue(hL, 1), lua_remove(hL, -2))
                ;
            lua_rawset(hL, -3);
            lua_pop(hL, 1);
        }
    }
    lua_pop(hL, 1);
    if (LUA_TTABLE == lua_getglobal(hL, "io")) {
        lua_pushstring(hL, "write");
        lua_pushvalue(hL, -1);
        lua_rawget(hL, -3);
        enable
            ? lua_pushcclosure(hL, redirect_io_write, 1)
            : (lua_getuservalue(hL, 1), lua_remove(hL, -2))
            ;
        lua_rawset(hL, -3);
    }
    lua_pop(hL, 1);
    return 0;
}

extern "C" 
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_remotedebug_stdio(lua_State* L) {
    lua_newtable(L);
    static luaL_Reg lib[] = {
        { "redirect", redirect },
        { "open_print", open_print },
        { "open_iowrite", open_iowrite },
        { NULL, NULL },
    };
    luaL_setfuncs(L, lib, 0);
    return 1;
}

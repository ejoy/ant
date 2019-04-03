#include <lua.hpp>
#include <new>
#include <limits>
#include <Windows.h>
#include "rdebug_redirect.h"

extern "C" {
lua_State* get_host(lua_State *L);
}

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
    size_t rc = self.read(buf, len);
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

extern "C" 
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_remotedebug_stdio(lua_State* L) {
    lua_newtable(L);
    static luaL_Reg lib[] = {
        { "redirect", redirect },
        { NULL, NULL },
    };
    luaL_setfuncs(L, lib, 0);
    return 1;
}

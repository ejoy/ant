#include "runtime.h"
#include <string.h>

#if defined(_WIN32)
#include <Windows.h>

static const char* lua_pushutf8string(lua_State* L, const wchar_t* wstr) {
    int usz = WideCharToMultiByte(CP_UTF8, 0, wstr, (int)-1, 0, 0, NULL, NULL);
    if (usz <= 0) {
        luaL_error(L, "convert to utf-8 string fail.");
        return 0;
    }
    void *ud;
    lua_Alloc allocf = lua_getallocf(L, &ud);
    char* ustr = (char*)allocf(ud, NULL, 0, usz);
    if (!ustr) {
        luaL_error(L, "convert to utf-8 string fail.");
        return 0;
    }
    int rusz = WideCharToMultiByte(CP_UTF8, 0, wstr, (int)-1, ustr, usz, NULL, NULL);
    if (rusz <= 0) {
        allocf(ud, ustr, usz, 0);
        luaL_error(L, "convert to utf-8 string fail.");
        return 0;
    }
    const char* r = lua_pushlstring(L, ustr, rusz-1);
    allocf(ud, ustr, usz, 0);
    return r;
}
#define PUSH_COMMAND lua_pushutf8string
#else
#define PUSH_COMMAND lua_pushstring
#endif

static int msghandler(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg == NULL) {
        lua_pushstring(L, "<null>");
    }
    luaL_traceback(L, L, msg, 1);
    return 1;
}

void pushprogdir(lua_State *L);

static void dostring(lua_State* L, const char* str) {
    lua_pushcfunction(L, msghandler);
    int err = lua_gettop(L);
    if (LUA_OK == luaL_loadbuffer(L, str, strlen(str), "=(BOOTSTRAP)")) {
        pushprogdir(L);
        if (LUA_OK == lua_pcall(L, 1, 0, err)) {
            return;
        }
    }
    lua_error(L);
}

static void createargtable(lua_State *L, int argc, RT_COMMAND argv) {
    lua_createtable(L, argc - 1, 0);
    for (int i = 1; i < argc; ++i) {
        PUSH_COMMAND(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");
}

static int pmain(lua_State *L) {
    int argc = (int)lua_tointeger(L, 1);
    RT_COMMAND argv = (RT_COMMAND)lua_touserdata(L, 2);
    luaL_checkversion(L);
    lua_pushboolean(L, 1);
    lua_setfield(L, LUA_REGISTRYINDEX, "LUA_NOENV");
    luaL_openlibs(L);
    createargtable(L, argc, argv);
    lua_gc(L, LUA_GCGEN, 0, 0);
    dostring(L, R"=(
local __ANT_RUNTIME__ = package.preload.firmware ~= nil
if __ANT_RUNTIME__ then
    assert(loadfile '/engine/firmware/bootstrap.lua')(...)
else
    local root = ...
    local f = assert(io.open(root.."main.lua"))
    local data = f:read "a"
    f:close()
    assert(load(data, "=(main.lua)"))()
end
)=");
    return 0;
}

void runtime_main(int argc, RT_COMMAND argv, void(*errfunc)(const char*)) {
    lua_State* L = luaL_newstate();
    if (!L) {
        errfunc("cannot create state: not enough memory");
        return;
    }
    lua_pushcfunction(L, &pmain);
    lua_pushinteger(L, argc);
    lua_pushlightuserdata(L, argv);
    if (LUA_OK != lua_pcall(L, 2, 0, 0)) {
        errfunc(lua_tostring(L, -1));
    }
    lua_close(L);
}

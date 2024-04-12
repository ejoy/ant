#include "runtime.h"
#include <string.h>
#include <bee/utility/path_helper.h>
#include <bee/nonstd/unreachable.h>

#if defined(_WIN32)
#include <bee/platform/win/wtf8.h>
#endif

static int msghandler(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg == NULL) {
        lua_pushstring(L, "<null>");
    }
    luaL_traceback(L, L, msg, 1);
    return 1;
}

static void pushprogdir(lua_State* L) {
    auto exepath = bee::path_helper::exe_path();
    if (!exepath) {
        luaL_error(L, "unable to get progdir: %s\n", exepath.error().c_str());
        std::unreachable();
    }
    auto progdir = exepath.value().remove_filename();
#if defined(_WIN32)
    auto str = bee::wtf8::w2u(progdir.generic_wstring());
#else
    auto str = progdir.generic_string();
#endif
    lua_pushlstring(L, str.data(), str.size());
}

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

static void createargtable(lua_State *L, int argc, char** argv) {
    lua_createtable(L, argc - 1, 0);
    for (int i = 1; i < argc; ++i) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");
}

static int pmain(lua_State *L) {
    int argc = (int)lua_tointeger(L, 1);
    char** argv = (char**)lua_touserdata(L, 2);
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

void runtime_main(int argc, char** argv, void(*errfunc)(const char*)) {
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

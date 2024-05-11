#include "runtime.h"

static int msghandler(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg == NULL) {
        lua_pushstring(L, "<null>");
    }
    luaL_traceback(L, L, msg, 1);
    return 1;
}

template <size_t size>
static void dostring(lua_State* L, const char (&str)[size]) {
    lua_pushcfunction(L, msghandler);
    int err = lua_gettop(L);
    if (LUA_OK == luaL_loadbuffer(L, str, size-1, "=(BOOTSTRAP)")) {
        if (LUA_OK == lua_pcall(L, 0, 0, err)) {
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
local fastio = require "fastio"
do
    local function LoadFile(path, env)
        local data = fastio.readall_v(path, path)
        local func, err = fastio.loadlua(data, path, env)
        if not func then
            error(err)
        end
        return func
    end
    local function LoadDbg(expr)
        local env = setmetatable({}, {__index = _G})
        function env.dofile(path)
            return LoadFile(path, env)()
        end
        assert(load(expr, "=(expr)", "t", env))()
    end
    local i = 1
    while true do
        if arg[i] == nil then
            break
        elseif arg[i] == '-e' then
            assert(arg[i + 1], "'-e' needs argument")
            LoadDbg(arg[i + 1])
            table.remove(arg, i)
            table.remove(arg, i)
            break
        end
        i = i + 1
    end
end
if __ANT_RUNTIME__ then
    fastio.set_readability(false)
    dofile "/engine/firmware/bootstrap.lua"
else
    local mainfunc; do
        local sys = require "bee.sys"
        local progdir = assert(sys.exe_path()):remove_filename():string()
        local mainlua = progdir.."main.lua"
        local f <close> = assert(io.open(mainlua, "rb"))
        local data = f:read "a"
        mainfunc = assert(load(data, "@"..mainlua))
    end
    mainfunc()
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

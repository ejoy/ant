#include <lua.hpp>
#include <string>
#include <string_view>
#include <mutex>

#include "../luabind/luavalue.h"

std::string initfunc;
luavalue::table initargs;
std::mutex mutex;

static const std::string_view initscript = R"(
local initfunc, initargs = ...
local vfs = {}
local fastio = require "fastio"
local __ANT_RUNTIME__ = package.preload.firmware ~= nil
if __ANT_RUNTIME__ then
    local fw = require "firmware"
    function vfs.read(path)
        assert(path:sub(1, 17) == "/engine/firmware/")
        local data = fw.readall_v(path:sub(18))
        return data, path
    end
else
    function vfs.read(path)
        assert(path:sub(1, 1) == "/")
        local lpath = path:sub(2)
        local data = fastio.readall_v(lpath, path)
        return data, lpath
    end
end
function loadfile(path, _, env)
    local mem, symbol = vfs.read(path)
    if not mem then
        return nil, ('%s:No such file or directory.'):format(path)
    end
    return fastio.loadlua(mem, symbol, env)
end
function dofile(path)
    local f, err = loadfile(path)
    if not f then
        error(err)
    end
    return f()
end
local function searcher_lua(name)
    local filename = name:gsub('%.', '/')
    local path = package.path:gsub('%?', filename)
    local mem, symbol = vfs.read(path)
    if mem then
        local func, err = fastio.loadlua(mem, symbol, env)
        if not func then
            error(("error loading module '%s' from file '%s':\n\t%s"):format(name, path, err))
        end
        return func
    end
    return "no file '"..path.."'"
end
local searcher_preload = package.searchers[1]
package.searchers = {
    searcher_preload,
    searcher_lua,
}
if initfunc then
    assert(loadfile(initfunc))(vfs, initargs)
end
return vfs
)";

static const std::string_view updateinitfunc = R"(
local vfs, initfunc, initargs = ...
if initfunc then
    assert(loadfile(initfunc))(vfs, initargs)
end
)";

#define LoadScript(L, script) if (luaL_loadbuffer(L, script.data(), script.size(), "=(vfs)") != LUA_OK) { return lua_error(L); }

static int setinitfunc(lua_State* L) {
    size_t sz_initfunc = 0;
    const char* s_initfunc = luaL_checklstring(L, 1, &sz_initfunc);
    std::lock_guard<std::mutex> lock(mutex);
    initfunc.assign(s_initfunc, sz_initfunc);
    luavalue::set(L, 2, initargs);
    if (!lua_toboolean(L, 3)) {
        LoadScript(L, updateinitfunc);
        lua_pushvalue(L, lua_upvalueindex(1));
        lua_pushvalue(L, 1);
        lua_pushvalue(L, 2);
        lua_call(L, 3, 0);
    }
    return 0;
}

static int push_initfunc(lua_State* L) {
    std::lock_guard<std::mutex> lock(mutex);
    if (initfunc.empty()) {
        return 0;
    }
    lua_pushlstring(L, initfunc.data(), initfunc.size());
    luavalue::get(L, initargs);
    return 2;
}

extern "C"
int luaopen_vfs(lua_State* L) {
    LoadScript(L, initscript);
    lua_call(L, push_initfunc(L), 1);
    luaL_Reg l[] = {
        {"initfunc", setinitfunc},
        {NULL, NULL},
    };
    lua_pushvalue(L, -1);
    luaL_setfuncs(L, l, 1);
    return 1;
}

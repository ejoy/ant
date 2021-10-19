#include <lua.hpp>
#include <string>
#include <string_view>
#include <mutex>

std::string initfunc;
std::string initargs;
std::mutex mutex;

static const std::string_view initscript = R"(
local initfunc, initargs = ...
local vfs = {}
local io_open = io.open
local runtime = package.preload.firmware ~= nil
function vfs.realpath(path)
    if not runtime then
        return path
    end
    local fw = require "firmware"
    local repopath = "./"
    local rawvfs = assert(fw.loadfile "vfs.lua")()
    local repo = rawvfs.new(repopath)
    local function realpath(path)
        local r = repo:realpath(path)
        return assert(r, "Not exists "..path)
    end
    local function dofile(path)
        local f = assert(io.open(realpath(path)))
        local str = f:read "a"
        f:close()
        return assert(load(str, "@" .. path))()
    end
    rawvfs = dofile "engine/firmware/vfs.lua"
    repo = rawvfs.new(repopath)
    vfs.realpath = realpath
    return realpath(path)
end
local function errmsg(err, filename, real_filename)
    local first, last = err:find(real_filename, 1, true)
    if not first then
        return err
    end
    return err:sub(1, first-1) .. filename .. err:sub(last+1)
end
function vfs.loadfile(path, ...)
    local realpath = vfs.realpath(path)
    if not realpath then
        return nil, ('%s:No such file or directory.'):format(path)
    end
    local f, err, ec = io_open(realpath, 'rb')
    if not f then
        err = errmsg(err, path, realpath)
        return nil, err, ec
    end
    local str = f:read 'a'
    f:close()
    if runtime then
        return load(str, '@' .. path, ...)
    else
        return load(str, '@' .. realpath, ...)
    end
end
function vfs.dofile(path)
    local f, err = vfs.loadfile(path)
    if not f then
        error(err)
    end
    return f()
end
function vfs.searchpath(name, path)
    local err = ''
    name = string.gsub(name, '%.', '/')
    for c in string.gmatch(path, '[^;]+') do
        local filename = string.gsub(c, '%?', name)
        if vfs.realpath(filename) then
            return filename
        end
        err = err .. ("\n\tno file '%s'"):format(filename)
    end
    return nil, err
end
function vfs.searcher_Lua(name)
    assert(type(package.path) == "string", "'package.path' must be a string")
    local filename, err = vfs.searchpath(name, package.path)
    if not filename then
        return err
    end
    local func, err = vfs.loadfile(filename)
    if not func then
        error(("error loading module '%s' from file '%s':\n\t%s"):format(name, filename, err))
    end
    return func, filename
end
if initfunc then
    assert(vfs.loadfile(initfunc))(vfs, initargs)
end
package.searchers[2] = vfs.searcher_Lua
package.searchpath = vfs.searchpath
loadfile = vfs.loadfile
dofile = vfs.dofile
return vfs
)";

static const std::string_view updateinitfunc = R"(
local vfs, initfunc, initargs = ...
if initfunc then
    assert(vfs.loadfile(initfunc))(vfs, initargs)
end
)";

#define LoadScript(L, script) if (luaL_loadbuffer(L, script.data(), script.size(), script.data()) != LUA_OK) { return lua_error(L); }

static int setinitfunc(lua_State* L) {
    size_t sz_initfunc = 0;
    size_t sz_initargs = 0;
    const char* s_initfunc = luaL_checklstring(L, 1, &sz_initfunc);
    const char* s_initargs = luaL_optlstring(L, 2, "", &sz_initargs);
    std::lock_guard<std::mutex> lock(mutex);
    initfunc.assign(s_initfunc, sz_initfunc);
    initargs.assign(s_initargs, sz_initargs);
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
    lua_pushlstring(L, initargs.data(), initargs.size());
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

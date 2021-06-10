#include <lua.hpp>

static const char script_init[] = R"(
local vfs = {}
local io_open = io.open
function vfs.realpath(path)
    local repopath = "./"
    local fw = require "firmware"
    local rawvfs = assert(fw.loadfile "vfs.lua")()
    local repo = rawvfs.new(repopath)
    local function realpath(path)
        local r = repo:realpath(path)
        return r
    end
    local function dofile(path)
        local f = assert(io.open(realpath(path)))
        local str = f:read "a"
        f:close()
        return assert(load(str, "@/" .. path))()
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
function vfs.openfile(filename)
    local real_filename = vfs.realpath(filename)
    if not real_filename then
        return nil, ('%s:No such file or directory.'):format(filename)
    end
    local f, err, ec = io_open(real_filename, 'rb')
    if not f then
        err = errmsg(err, filename, real_filename)
        return nil, err, ec
    end
    return f
end
function vfs.loadfile(path)
    local f, err = vfs.openfile(path)
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@/' .. path)
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
package.searchers[2] = vfs.searcher_Lua
package.searchpath = vfs.searchpath
return vfs
)";

#define LoadScript(L, script) if (luaL_loadbuffer(L, script, sizeof(script) - 1, "=module 'vfs'") != LUA_OK) { return lua_error(L); }

extern "C"
int luaopen_vfs(lua_State* L) {
    LoadScript(L, script_init);
    lua_call(L, 0, 1);
    return 1;
}

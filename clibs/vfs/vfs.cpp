#include <lua.hpp>
#include <string_view>

using namespace std::literals;

static constexpr std::string_view initscript = R"(
local vfs = {}
local fastio = require "fastio"
__ANT_RUNTIME__ = package.preload.firmware ~= nil
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
function loadfile(path)
    local mem, symbol = vfs.read(path)
    if not mem then
        return nil, ('%s:No such file or directory.'):format(path)
    end
    return fastio.loadlua(mem, symbol)
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
        local func, err = fastio.loadlua(mem, symbol)
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
return vfs
)"sv;

extern "C"
int luaopen_vfs(lua_State* L) {
    if (luaL_loadbuffer(L, initscript.data(), initscript.size(), "=(vfs)") != LUA_OK) {
        return lua_error(L);
    }
    lua_call(L, 0, 1);
    return 1;
}

#include <lua.hpp>
#include <string>
#include <string_view>
#include <mutex>
#include <variant>

template<class> inline constexpr bool always_false_v = false;

struct lua_value {
    std::variant<
        std::monostate, // LUA_TNIL
        bool,           // LUA_TBOOLEAN
        void*,          // LUA_TLIGHTUSERDATA
        lua_Integer,    // LUA_TNUMBER
        lua_Number,     // LUA_TNUMBER
        std::string,    // LUA_TSTRING
        lua_CFunction   // LUA_TFUNCTION
    > storage;

    void set(lua_State* L, int idx) {
        switch (lua_type(L, idx)) {
        case LUA_TNIL:
            storage.emplace<std::monostate>();
            break;
        case LUA_TBOOLEAN:
            storage.emplace<bool>(!!lua_toboolean(L, idx));
            break;
        case LUA_TLIGHTUSERDATA:
            storage.emplace<void*>(lua_touserdata(L, idx));
            break;
        case LUA_TNUMBER:
            if (lua_isinteger(L, idx)) {
                storage.emplace<lua_Integer>(lua_tointeger(L, idx));
            }
            else {
                storage.emplace<lua_Number>(lua_tonumber(L, idx));
            }
            break;
        case LUA_TSTRING: {
            size_t sz = 0;
            const char* str = lua_tolstring(L, idx, &sz);
            storage.emplace<std::string>(str, sz);
            break;
        }
        case LUA_TFUNCTION: {
            lua_CFunction func = lua_tocfunction(L, idx);
            if (func == NULL || lua_getupvalue(L, idx, 1) != NULL) {
                luaL_error(L, "Only light C function can be serialized");
                return;
            }
            storage.emplace<lua_CFunction>(func);
            break;
        }
        default:
            luaL_error(L, "Unsupport type %s to serialize", lua_typename(L, idx));
        }
    }

    void get(lua_State* L) {
        std::visit([=](auto&& arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, std::monostate>) {
                lua_pushnil(L);
            } else if constexpr (std::is_same_v<T, bool>) {
                lua_pushboolean(L, arg);
            } else if constexpr (std::is_same_v<T, void*>) {
                lua_pushlightuserdata(L, arg);
            } else if constexpr (std::is_same_v<T, lua_Integer>) {
                lua_pushinteger(L, arg);
            } else if constexpr (std::is_same_v<T, lua_Number>) {
                lua_pushnumber(L, arg);
            } else if constexpr (std::is_same_v<T, std::string>) {
                lua_pushlstring(L, arg.data(), arg.size());
            } else if constexpr (std::is_same_v<T, lua_CFunction>) {
                lua_pushcfunction(L, arg);
            } else {
                static_assert(always_false_v<T>, "non-exhaustive visitor!");
            }
        }, storage);
    }
};

std::string initfunc;
lua_value initargs;
std::mutex mutex;

static const std::string_view initscript = R"(
local initfunc, initargs = ...
local vfs = {}
local io_open = io.open
local supportFirmware = package.preload.firmware ~= nil
function vfs.realpath(path)
    if not supportFirmware then
        return path
    end
    local fw = require "firmware"
    local repopath = "./"
    local rawvfs = assert(fw.loadfile "vfs.lua")()
    local repo = rawvfs.new(repopath)
    local function realpath(path)
        local r = repo:realpath(path)
        if not r then
            error("Not exists "..path)
        end
        return r
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
    if supportFirmware then
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

#define LoadScript(L, script) if (luaL_loadbuffer(L, script.data(), script.size(), "=(vfs)") != LUA_OK) { return lua_error(L); }

static int setinitfunc(lua_State* L) {
    size_t sz_initfunc = 0;
    const char* s_initfunc = luaL_checklstring(L, 1, &sz_initfunc);
    std::lock_guard<std::mutex> lock(mutex);
    initfunc.assign(s_initfunc, sz_initfunc);
    initargs.set(L, 2);
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
    initargs.get(L);
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

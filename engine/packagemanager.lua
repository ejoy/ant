--TODO: remove they
require "log"
require "filesystem"
require "directory"

local vfs = require "vfs"
local fastio = require "fastio"

local registered = {}

local function searchpath(name, path)
    name = string.gsub(name, '%.', '/')
    for c in string.gmatch(path, '[^;]+') do
        local filename = string.gsub(c, '%?', name)
        if vfs.type(filename) ~= nil then
            return filename
        end
    end
    return nil, "no file '"..path:gsub(';', "'\n\tno file '"):gsub('%?', name).."'"
end

local function sandbox_env(packagename)
    local env = setmetatable({}, {__index=_G})
    local _LOADED = {}
    local _PRELOAD = package.preload
    local PATH = "/pkg/"..packagename..'/?.lua'

    local function searcher_preload(name)
        local func = _PRELOAD[name]
        if func then
            return func
        end
        return ("no field package.preload['%s']"):format(name)
    end

    local function searcher_lua(name)
        local filename = name:gsub('%.', '/')
        local path = PATH:gsub('%?', filename)
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

    function env.require(name)
        local _ = type(name) == "string" or error (("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = _LOADED[name] or package.loaded[name]
        if p ~= nil then
            return p
        end
        local initfunc = searcher_preload(name)
        if type(initfunc) == "function" then
            local r = initfunc()
            if r == nil then
                r = true
            end
            package.loaded[name] = r
            return r
        end
        initfunc = searcher_lua(name)
        if type(initfunc) == "function" then
            local r = initfunc()
            if r == nil then
                r = true
            end
            _LOADED[name] = r
            return r
        end
        local filename = name:gsub('%.', '/')
        local path = PATH:gsub('%?', filename)
        error(("module '%s' not found:\n\tno field package.preload['%s']\n\tno file '%s'"):format(name, name, path))
    end

    env.package = {
        config = table.concat({"/",";","?","!","-"}, "\n"),
        loaded = _LOADED,
        preload = _PRELOAD,
        path = PATH,
        cpath = "",
        searchpath = searchpath,
        searchers = {
            searcher_preload,
            searcher_lua,
        }
    }
    return env
end

local function loadenv(name)
    local env = registered[name]
    if not env then
        if vfs.type("/pkg/"..name) ~= 'dir' then
            error(('`/pkg/%s` is not a directory.'):format(name))
        end
        env = sandbox_env(name)
        registered[name] = env
    end
    return env
end

local function import(name)
    return loadenv(name).require "main"
end

---@diagnostic disable-next-line: lowercase-global
import_package = import

return {
    import = import,
    loadenv = loadenv,
}

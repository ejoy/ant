local vfs = require "vfs"
local fastio = require "fastio"

local registered = {}

local function sandbox_env(packagename)
    local env = {}
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

    function env.loadfile(path)
        local filename = "/pkg/"..packagename.."/"..path
        local mem, symbol = vfs.read(filename)
        if not mem then
            return nil, ("file '%s' not found"):format(filename)
        end
        local func, err = fastio.loadlua(mem, symbol, env)
        if not func then
            return nil, ("error loading file '%s':\n\t%s"):format(filename, err)
        end
        return func
    end

    env.package = {
        loaded = _LOADED,
        preload = _PRELOAD,
        searchers = {
            searcher_preload,
            searcher_lua,
        }
    }
    return setmetatable(env, {__index=_G})
end

local function loadenv(name)
    local env = registered[name]
    if not env then
        if vfs.type("/pkg/"..name) ~= "d" then
            error(('`/pkg/%s` is not a directory.'):format(name))
        end
        env = sandbox_env(name)
        registered[name] = env
    end
    return env
end

function import_package(name)
    return loadenv(name).require "main"
end

return {
    loadenv = loadenv,
}

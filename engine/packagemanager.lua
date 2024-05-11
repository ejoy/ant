local vfs = require "vfs"
local fastio = require "fastio"
local platform = require "bee.platform"

local AllowDll <const> = platform.os ~= "ios"

local dllpath; do
    if platform.os == "windows" then
        function dllpath(name)
            return name..".dll"
        end
    else
        local sys = require "bee.sys"
        local procdir = sys.exe_path():remove_filename():string()
        function dllpath(name)
            return procdir..name..".so"
        end
    end
end
local registered = {}

local function sandbox_env(packagename)
    local env = {}
    local _LOADED = {}
    local _PRELOAD = package.preload
    local PATH <const> = "/pkg/"..packagename..'/?.lua'

    function env.require(name)
        local _ = type(name) == "string" or error (("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = _LOADED[name] or package.loaded[name]
        if p ~= nil then
            return p
        end
        do
            local func = _PRELOAD[name]
            if func then
                local r = func()
                if r == nil then
                    r = true
                end
                package.loaded[name] = r
                return r
            end
        end
        local filename = name:gsub('%.', '/')
        local path = PATH:gsub('%?', filename)
        do
            local mem, symbol = vfs.read(path)
            if mem then
                local func, err = fastio.loadlua(mem, symbol, env)
                if not func then
                    error(("error loading module '%s' from file '%s':\n\t%s"):format(name, path, err))
                end
                local r = func()
                if r == nil then
                    r = true
                end
                _LOADED[name] = r
                return r
            end
        end
        if AllowDll then
            local funcname = "luaopen_"..name:gsub('%.', '_')
            local func = package.loadlib(dllpath(name:match('^[^.]*')), funcname)
            if func ~= nil then
                local r = func()
                if r == nil then
                    r = true
                end
                _LOADED[name] = r
                return r
            end
        end
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

    function env.dofile(path)
        local func, err = env.loadfile(path)
        if not func then
            error(err)
        end
        return func()
    end

    env.package = {
        loaded = _LOADED,
        preload = _PRELOAD,
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

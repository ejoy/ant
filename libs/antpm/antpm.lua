local fs = require "filesystem"
local sandbox = require "antpm.sandbox"

local WORKDIR = fs.vfs and fs.path 'engine' or fs.current_path()

local list = {
    WORKDIR / "libs",

    WORKDIR / "packages" / "math",
    WORKDIR / "packages" / "inputmgr",
    WORKDIR / "packages" / "modelloader",
    WORKDIR / "packages" / "editor",
    WORKDIR / "packages" / "render",
    WORKDIR / "packages" / "serialize",
    WORKDIR / "packages" / "asset",
}
local registered = {}
local loaded = {}

local function loadfile(path)
    local f, err = fs.open(path, 'r')
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@' .. path:string())
end
local function dofile(path)
    local f, err = loadfile(path)
    if not f then
        error(err)
    end
    return f()
end

local function register(pkg)
    if not fs.exists(pkg) then
        error(('Cannot find package `%s`.'):format(pkg:string()))
    end
    local cfg = pkg / "package.lua"
    if not fs.exists(cfg) then
        error(('Cannot find package config `%s`.'):format(cfg:string()))
    end
    local config = dofile(cfg)
    for _, field in ipairs {'name'} do
        if not config[field] then
            error(('Missing `%s` field in `%s`.'):format(field, cfg:string()))
        end 
    end
    if registered[config.name] then
        error(('Duplicate definition package `%s` in `%s`.'):format(pkg.name, pkg:string()))
    end
    registered[config.name] = { pkg, config }
    return config.name
end

local function require_package(name)
    if not registered[name] or not registered[name][2].entry then
        error(("\n\tno package '%s'"):format(name))
    end
    local info = registered[name]
    return sandbox.require(info[1]:string(), info[2].entry)
end

for _, pkg in ipairs(list) do
    register(pkg)
end

local function import(name)
    if loaded[name] then
        return loaded[name]
    end
    local res = require_package(name)
    if res == nil then
        loaded[name] = false
    else
        loaded[name] = res
    end
    return loaded[name]
end

local function find(name)
    if not registered[name] then
        return
    end
    return registered[name][1], registered[name][2]
end

local function m_loadfile(name, filename)
    return fs.loadfile(filename, 't', sandbox.env(registered[name][1]:string()))
end

return {
    find = find,
    register = register,
    import = import,
    loadfile = m_loadfile,
    ecs_modules = require "antpm.ecs_modules"
}

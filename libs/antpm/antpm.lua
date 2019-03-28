local sandbox = require "antpm.sandbox"
local vfs = require "vfs.simplefs"
local dofile = dofile

local registered = {}
local loaded = {}

local function register(pkg)
    if not vfs.type(pkg) then
        error(('Cannot find package `%s`.'):format(pkg))
    end
    local cfg = vfs.join(pkg, "package.lua")
    if not vfs.type(cfg) then
        error(('Cannot find package config `%s`.'):format(cfg))
    end
    local cfgpath = assert(vfs.realpath(cfg))
    local config = dofile(cfgpath)
    for _, field in ipairs {'name'} do
        if not config[field] then
            error(('Missing `%s` field in `%s`.'):format(field, cfg))
        end 
    end
    if registered[config.name] then
        error(('Duplicate definition package `%s` in `%s`.'):format(config.name, pkg))
    end
    registered[config.name] = {
        root = pkg,
        config = config,
    }
    return config.name
end

local function require_package(name)
    if not registered[name] or not registered[name].config.entry then
        error(("\n\tno package '%s'"):format(name))
    end
    local info = registered[name]
    if not info.env then
		info.env = sandbox.env("//"..name, name)
    end
    return info.env.require(info.config.entry)
end

local packagedir = 'engine/packages'
for pkg in vfs.each(packagedir) do
    register(vfs.join(packagedir, pkg))
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

local function test(name, entry)
    if not registered[name] then
        error(("\n\tno package '%s'"):format(name))
    end
    local info = registered[name]
    if not info.env then
		info.env = sandbox.env("//"..name, name)
    end
    return info.env.require(entry or 'test')
end

local function find(name)
    if not registered[name] then
        return
    end
    return registered[name].root, registered[name].config
end

local function m_loadfile(filename)
    local name = filename:root_name():string():sub(3)
    local info = registered[name]
    if not info.env then
        info.env = sandbox.env("//"..name, name)
    end
    local fs = require "filesystem"
    return fs.loadfile(filename, 't', info.env)
end

local function setglobal(name, value)
    _G[name] = value
end

return {
    find = find,
    register = register,
    import = import,
    test = test,
    loadfile = m_loadfile,
    setglobal = setglobal,
}

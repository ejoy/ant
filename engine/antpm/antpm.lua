local sandbox = require "antpm.sandbox"
local vfs = require "vfs.simplefs"
local lfs = require "filesystem.cpp"
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
        config = config
    }
    return config.name
end

local function require_package(name)
    if not registered[name] or not registered[name].config.entry then
        error(("\n\tno package '%s'"):format(name))
    end
    local info = registered[name]
    if not info.env then
		info.env = sandbox.env("/pkg/"..name, name)
    end
    return info.env.require(info.config.entry)
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

local function config(name)
    if not registered[name] then
        return
    end
    return registered[name].config
end

local function pm_loadfile(filename)
    local name = filename:package_name()
    local info = registered[name]
    if not info.env then
        info.env = sandbox.env("/pkg/"..name, name)
    end
    local fs = require "filesystem"
    return fs.loadfile(filename, 't', info.env)
end

local function init()
    for pkg in vfs.each('/pkg') do
        register(vfs.join('/pkg', pkg))
    end
end

local function load_package(path)
    if not lfs.is_directory(path) then
        error(('`%s` is not a directory.'):format(path:string()))
    end
    local cfgpath = path / "package.lua"
    if not lfs.exists(cfgpath) then
        error(('`%s` does not exist.'):format(cfgpath:string()))
    end
    local config = dofile(cfgpath:string())
    for _, field in ipairs {'name'} do
        if not config[field] then
            error(('Missing `%s` field in `%s`.'):format(field, cfgpath:string()))
        end 
    end
    return config.name
end

local function load_packages(dir)
    local res = {}
    for path in dir:list_directory() do
        local ok, name = pcall(load_package, path)
        if ok then
            if res[name] then
                error(('Duplicate definition package `%s` in `%s`.'):format(name, path:string()))
            end
            res[name] = path
        end
    end
    return res
end

local function register_package(path)
    if __ANT_RUNTIME__ then
        return false
    end
    local name = load_package(path)
    local editorvfs = require "vfs"
    editorvfs.add_mount("pkg/"..name, path)
    return register(vfs.join('/pkg', name))
end

return {
    import = import,
    test = test,
    loadfile = pm_loadfile,
    init = init,
    config = config,
    load_package = load_package,
    load_packages = load_packages,
    register_package = register_package,
}

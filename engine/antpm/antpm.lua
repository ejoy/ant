local sandbox = require "antpm.sandbox"
local vfs = require "vfs.simplefs"
local lfs = require "filesystem.cpp"
local dofile = dofile

local registered = {}
local loaded = {}
local entry_pkg = nil

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
    entry_pkg = entry_pkg or name
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
		info.env = sandbox.env("/pkg/"..name, name)
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
    if registered[config.name] then
        error(('Duplicate definition package `%s` in `/pkg/%s`.'):format(config.name, config.name))
    end
    registered[config.name] = {
        config = config
    }
    return config.name
end

local function get_registered(path)
    if __ANT_RUNTIME__ then
        return false
    end
    local name = load_package(path)
    return registered[name]
end

local function register_package(path,force)
    if __ANT_RUNTIME__ then
        return false
    end
    local name = load_package(path)
    if registered[name] and force then
        registered[name] = nil
    end
    local editorvfs = require "vfs"
    editorvfs.unmount("pkg/"..name)
    editorvfs.add_mount("pkg/"..name, path)
    return name
end

local function get_entry_pkg()
    if entry_pkg then
        return vfs.join('/pkg', entry_pkg)
    end
end

return {
    import = import,
    test = test,
    loadfile = pm_loadfile,
    get_entry_pkg = get_entry_pkg,
    get_registered = get_registered,
    config = config,
    load_package = load_package,
    register_package = register_package,
}

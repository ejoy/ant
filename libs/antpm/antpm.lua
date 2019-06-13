local sandbox = require "antpm.sandbox"
local vfs = require "vfs.simplefs"
require "editor.vfs"
local editorvfs = require "vfs"
local lfs = require "filesystem.cpp"
local dofile = dofile

local registered = {}
local loaded = {}

local function register(localpath)
    if not lfs.is_directory(localpath) then
        error(('`%s` is not a directory.'):format(localpath:string()))
    end
    local cfgpath = localpath / "package.lua"
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
        error(('Duplicate definition package `%s` in `%s`.'):format(config.name, localpath:string()))
    end
    editorvfs.add_mount("pkg/"..config.name, localpath)
    registered[config.name] = {
        root = "/pkg/"..config.name,
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
		info.env = sandbox.env("/pkg/"..name, name)
    end
    return info.env.require(info.config.entry)
end

local packagedir = 'engine/packages'
for pkg in vfs.each(packagedir) do
    register(lfs.path(vfs.realpath(vfs.join(packagedir, pkg))))
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
    local name = filename:root_name():string():sub(6)
    local info = registered[name]
    if not info.env then
        info.env = sandbox.env("/pkg/"..name, name)
    end
    local fs = require "filesystem"
    return fs.loadfile(filename, 't', info.env)
end

local function setglobal(name, value)
    _G[name] = value
end


local function get_registered_list(sort)
    local t = {}
    for name,_ in pairs(registered) do
        table.insert(t,name)
    end
    if sort then
        table.sort(t)
    end
    return t
end


return {
    find = find,
    register = register,
    import = import,
    test = test,
    loadfile = m_loadfile,
    setglobal = setglobal,
	get_registered_list = get_registered_list,
}

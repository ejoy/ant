local sandbox = require "sandbox"
local fs  = require "filesystem"
local dofile = dofile

local initialized = false
local pathtoname = {}
local registered = {}
local loaded = {}

local function loadenv(name)
    local info = registered[name]
    if not info then
        error(("\n\tno package '%s'"):format(name))
    end
    if not info.env then
        info.env = sandbox.env("/pkg/"..name, name)
    end
    return info.env
end

local function import(name)
    if loaded[name] then
        return loaded[name]
    end
    local info = registered[name]
    if not info or not info.config.entry then
        return error(("no package '%s'"):format(name))
    end
    local res = loadenv(name).require(info.config.entry)
    if res == nil then
        loaded[name] = false
    else
        loaded[name] = res
    end
    return loaded[name]
end

local function register_package(path)
    if pathtoname[path] then
        return pathtoname[path]
    end
    if not fs.is_directory(path) then
        error(('`%s` is not a directory.'):format(path:string()))
    end
    local cfgpath = path / "package.lua"
    if not fs.exists(cfgpath) then
        error(('`%s` does not exist.'):format(cfgpath:string()))
    end
    local config = dofile(cfgpath:localpath():string())
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
    pathtoname[path] = config.name
    return config.name
end

local function initialize()
    if initialized then
        for path in fs.path'/pkg':list_directory() do
            if not registered[path:string():sub(6)] then
                register_package(path)
            end
        end
    else
        initialized = true
        for path in fs.path'/pkg':list_directory() do
            register_package(path)
        end
    end
end

initialize()
import_package = import

return {
    loadenv = loadenv,
}

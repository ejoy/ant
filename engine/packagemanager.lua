require "common.log"
local sandbox = require "sandbox"
local fs  = require "filesystem"

local pathtoname = {}
local registered = {}

local function loadenv(name)
    local info = registered[name]
    if not info then
        error(("\n\tno package '%s'"):format(name))
    end
    if not info.env then
        info.env = sandbox.env(loadenv, info.config, "/pkg/"..name)
    end
    return info.env
end

local function import(name)
    return loadenv(name).import_package(name)
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
    pathtoname[path] = config.name
    return config.name
end

local function initialize()
    for path in fs.pairs(fs.path'/pkg/') do
        register_package(path)
    end
end

initialize()
---@diagnostic disable-next-line: lowercase-global
import_package = import

return {
    import = import,
    loadenv = loadenv,
}

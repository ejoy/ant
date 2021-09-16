local sandbox = require "sandbox"
local fs  = require "filesystem"
local dofile = dofile

local pathtoname = {}
local registered = {}

local function loadenv(name)
    local info = registered[name]
    if not info then
        error(("\n\tno package '%s'"):format(name))
    end
    if not info.env then
        info.env = sandbox.env(loadenv, info.config, "/pkg/"..name, name)
        if info.config.entry then
            info.env._ENTRY = info.env.require(info.config.entry)
        end
    end
    return info.env
end

local function import(name)
    return loadenv(name)._ENTRY
end

local function import_ecs(name, file, ecs)
    return loadenv(name).require_ecs(file, ecs)
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
    for path in fs.path'/pkg':list_directory() do
        register_package(path)
    end
    for pkgname, info in pairs(registered) do
        local dependencies = info.config.dependencies
        if dependencies then
            for _, depname in ipairs(dependencies) do
                if not registered[depname] then
                    error(("package `%s` has undefined dependencies `%s`"):format(pkgname, depname))
                end
            end
        end
    end
end

initialize()
import_package = import

return {
    import_ecs = import_ecs,
}

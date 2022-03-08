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

local function detect_circular_dependency()
    local status = {}
    for pkgname in pairs(registered) do
        status[pkgname] = false
    end
    local function dfs(name)
        local dependencies = registered[name].config.sloved_dependencies
        for pkgname in pairs(dependencies) do
            if status[pkgname] == false then
                status[name] = pkgname
                dfs(pkgname)
            elseif status[pkgname] == true then
            else
                log.warn(("There is a circular dependency between `%s` and `%s`."):format(pkgname, status[pkgname]))
            end
        end
        status[name] = true
    end
    for pkgname in pairs(registered) do
        if status[pkgname] == false then
            dfs(pkgname)
        end
    end
end

local function detect()
    for pkgname, info in pairs(registered) do
        if info.config.dependencies then
            local dependencies = {}
            for _, depname in ipairs(info.config.dependencies) do
                if not registered[depname] then
                    log.error(("package `%s` has undefined dependencies `%s`"):format(pkgname, depname))
                end
                if dependencies[depname] then
                    log.error(("package `%s` repeat definition dependencies `%s`"):format(pkgname, depname))
                end
                dependencies[depname] = true
            end
        end
    end
    detect_circular_dependency()
end

local function initialize()
    for path in fs.pairs(fs.path'/pkg/') do
        register_package(path)
    end
    for _, info in pairs(registered) do
        local dependencies = {}
        if info.config.dependencies then
            for _, depname in ipairs(info.config.dependencies) do
                if registered[depname] then
                    dependencies[depname] = true
                end
            end
        end
        info.config.sloved_dependencies = dependencies
    end
end

initialize()
---@diagnostic disable-next-line: lowercase-global
import_package = import

local function findenv(from, to)
    return loadenv(from or to).package_env(to)
end

local function loadcfg(name)
    local info = registered[name]
    if not info then
        error(("\n\tno package '%s'"):format(name))
    end
    return info.config
end

return {
    import = import,
    findenv = findenv,
    loadenv = loadenv,
    detect = detect,
    loadcfg = loadcfg,
}

local fs = require "filesystem"

local WORKDIR = fs.current_path()

local list = {
    WORKDIR / "libs" / "math"
}
local registered = {}

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

local function init(pkg)
    if not fs.exists(pkg) then
        error(('Cannot find package `%s`.'):format(pkg:string()))
    end
    local cfg = pkg / "package.lua"
    if not fs.exists(cfg) then
        error(('Cannot find package config `%s`.'):format(cfg:string()))
    end
    local config = dofile(cfg)
    for _, field in ipairs {'name','main'} do
        if not config[field] then
            error(('Missing `%s` field in `%s`.'):format(field, cfg:string()))
        end 
    end
    if registered[config.name] then
        error(('Duplicate definition package `%s` in `%s`.'):format(pkg.name, pkg:string()))
    end
    registered[config.name] = { pkg, config }
end

local function searcher_Package(name)
    if not registered[name] then
        return ("\n\tno package '%s'"):format(name)
    end
    local info = registered[name]
    local func, err = loadfile(info[1] / info[2].main)
    if not func then
        error(("error loading package '%s':\n\t%s"):format(name, err))
    end
    return func, name
end

for _, pkg in ipairs(list) do
    init(pkg)
end

-- TODO 优先级应该提前
table.insert(package.searchers, 1, searcher_Package)

function import_package(name)
    local func = assert(searcher_Package(name))
    return func(func)
end

local sandbox = require "antpm.sandbox"
local vfs = require "vfs.simplefs"
local fs  = require "filesystem"
local dofile = dofile

local initialized = false
local pathtoname = {}
local registered = {}
local loaded = {}
local entry_pkg = nil

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

local function try_import(name)
    entry_pkg = entry_pkg or name
    if loaded[name] then
        return true, loaded[name]
    end
    local info = registered[name]
    if not info or not info.config.entry then
        return false, ("no package '%s'"):format(name)
    end
    local res = loadenv(name).require(info.config.entry)
    if res == nil then
        loaded[name] = false
    else
        loaded[name] = res
    end
    return true, loaded[name]
end

local function import(name)
    local ok, res = try_import(name)
    if not ok then
        error(res)
    end
    return res
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

local function unregister_package(path)
    local name = pathtoname[path]
    if not name then
        return
    end
    loaded[name] = nil
    registered[name] = nil
end

local function initialize()
    if initialized then
        entry_pkg = nil
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

local function get_registered(path)
    if __ANT_RUNTIME__ then
        return false
    end
    local name = pathtoname[path]
    if not name then
        return false
    end
    return registered[name]
end

local function editor_load_package(path,force)
    if __ANT_RUNTIME__ then
        return false
    end
    if force then
        unregister_package(path)
    end
    local name = register_package(path)
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
    loadenv = loadenv,
    import = import,
    try_import = try_import,
    register_package = register_package,
    unregister_package = unregister_package,
    initialize = initialize,
    --editor
    get_entry_pkg = get_entry_pkg,
    get_registered = get_registered,
    editor_load_package = editor_load_package,
}

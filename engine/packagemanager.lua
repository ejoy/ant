require "log" --TODO: remove it

local fs = require "filesystem"

local registered = {}

local function sandbox_env(loadenv, root)
    local env = setmetatable({}, {__index=_G})
    local _LOADED = {}

    local function searchpath(name, path)
        name = string.gsub(name, '%.', '/')
        for c in string.gmatch(path, '[^;]+') do
            local filename = string.gsub(c, '%?', name)
            if fs.exists(fs.path(filename)) then
                return filename
            end
        end
        return nil, "no file '"..path:gsub(';', "'\n\tno file '"):gsub('%?', name).."'"
    end

    local function searcher_lua(name)
        assert(type(env.package.path) == "string", "'package.path' must be a string")
        local path, err1 = searchpath(name, env.package.path)
        if not path then
            return err1
        end
        local func, err2 = loadfile(path)
        if not func then
            error(("error loading module '%s' from file '%s':\n\t%s"):format(name, path, err2))
        end
        return func, path
    end

    local function require_load(name, _SEARCHERS)
        local msg = ''
        assert(type(_SEARCHERS) == "table", "'package.searchers' must be a table")
        for i, searcher in ipairs(_SEARCHERS) do
            local f, extra = searcher(name)
            if type(f) == 'function' then
                return f, extra, i
            elseif type(f) == 'string' then
                msg = msg .. "\n\t" .. f
            end
        end
        error(("module '%s' not found:%s"):format(name, msg))
    end

    function env.require(name)
        assert(type(name) == "string", ("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = package.loaded[name] or _LOADED[name]
        if p ~= nil then
            return p
        end
        local initfunc, extra, idx = require_load(name, env.package.searchers)
        debug.setupvalue(initfunc, 1, env)
        local r = initfunc(name, extra)
        if r == nil then
            r = true
        end
        if idx == 2 then
            _LOADED[name] = r
        else
            package.loaded[name]= r
        end
        return r
    end

    local _ECS_LOADED = setmetatable({}, {__mode="k", __index=function(self, k)
        local t = {}
        self[k] = t
        return t
    end})
    local _ECS_LOADING = setmetatable({}, {__mode="k", __index=function(self, k)
        local t = {}
        self[k] = t
        return t
    end})
    local ecs_searchers = { searcher_lua }
    function env.require_ecs(w, ecs, name)
        assert(type(name) == "string", ("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = _ECS_LOADED[w][name]
        if p ~= nil then
            return p
        end
        if _ECS_LOADING[w][name] then
            error(("Recursive load module '%s'"):format(name))
        end
        local initfunc = require_load(name, ecs_searchers)
        debug.setupvalue(initfunc, 1, env)
        local r = initfunc(ecs)
        if r == nil then
            r = true
        end
        _ECS_LOADED[w][name] = r
        return r
    end
    function env.include_ecs(w, ecs, name)
        assert(type(name) == "string", ("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = _ECS_LOADED[w][name]
        if p ~= nil then
            return
        end
        if _ECS_LOADING[w][name] then
            return
        end
        _ECS_LOADING[w][name] = true
        local initfunc = require_load(name, ecs_searchers)
        debug.setupvalue(initfunc, 1, env)
        local r = initfunc(ecs)
        if r == nil then
            r = true
        end
        _ECS_LOADED[w][name] = r
        _ECS_LOADING[w][name] = nil
    end

    if fs.exists(fs.path(root.."/main.lua")) then
        env._ENTRY_FILE = "main"
    end
    function env.import_package(name)
        local e = loadenv(name)
        local f = e._ENTRY
        if f then
            return f
        end
        if e._ENTRY_FILE then
            f = e.require(e._ENTRY_FILE)
            e._ENTRY = f
            e._ENTRY_FILE = nil
            return f
        end
    end

    env.package = {
        config = table.concat({"/",";","?","!","-"}, "\n"),
        loaded = _LOADED,
        preload = package.preload,
        path = root .. '/?.lua',
        cpath = package.cpath,
        searchpath = searchpath,
        searchers = {}
    }
    for i, searcher in ipairs(package.searchers) do
        env.package.searchers[i] = searcher
    end
    env.package.searchers[2] = searcher_lua
    return env
end

local function loadenv(name)
    local info = registered[name]
    if not info then
        local path = fs.path("/pkg/"..name)
        if not fs.is_directory(path) then
            error(('`%s` is not a directory.'):format(path:string()))
        end
        info = {
            env = sandbox_env(loadenv, "/pkg/"..name)
        }
        registered[name] = info
    end
    return info.env
end

local function import(name)
    return loadenv(name).import_package(name)
end

---@diagnostic disable-next-line: lowercase-global
import_package = import

return {
    import = import,
    loadenv = loadenv,
}

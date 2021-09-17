local fs = require "filesystem"

local function sandbox_env(loadenv, config, root, pkgname)
    local env = setmetatable({}, {__index=_G})
    local _LOADED = {}
    local _ECS_LOADED = {}
    local _ECS_LOADING = {}

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

    local dependencies = {}
    if config.dependencies then
        for _, name in ipairs(config.dependencies) do
            dependencies[name] = true
        end
    end
    dependencies[pkgname] = true

    local ecs_searchers = { searcher_lua }
    function env.require_ecs(ecs, name)
        assert(type(name) == "string", ("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = _ECS_LOADED[name]
        if p ~= nil then
            return p
        end
        if _ECS_LOADING[name] then
            error(("Recursive load module '%s'"):format(name))
        end
        local initfunc = require_load(name, ecs_searchers)
        debug.setupvalue(initfunc, 1, env)
        local r = initfunc(ecs)
        if r == nil then
            r = true
        end
        _ECS_LOADED[name] = r
        return r
    end
    function env.include_ecs(ecs, name)
        assert(type(name) == "string", ("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = _ECS_LOADED[name]
        if p ~= nil then
            return
        end
        if _ECS_LOADING[name] then
            return
        end
        _ECS_LOADING[name] = true
        local initfunc = require_load(name, ecs_searchers)
        debug.setupvalue(initfunc, 1, env)
        local r = initfunc(ecs)
        if r == nil then
            r = true
        end
        _ECS_LOADED[name] = r
        _ECS_LOADING[name] = nil
    end

    function env.package_env(name)
        local error = log.error
        if not dependencies[name] then
            error(("package `%s` has no dependencies `%s`"):format(pkgname, name))
        end
        return loadenv(name)
    end

    function env.import_package(name)
        return env.package_env(name)._ENTRY
    end
    function env.import_ecs(ecs, name, file)
        return env.package_env(name).require_ecs(ecs, file)
    end
    function env.import_ecs_2(ecs, name, file)
        env.package_env(name).include_ecs(ecs, file)
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

return {
    env = sandbox_env,
}

local pm = require "packagemanager"

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
end

return function (w, importor, package)
    local ecs = { world = w }
    function ecs.system(name)
        local fullname = package .. "|" .. name
        local r = w._class.system[fullname]
        if r == nil then
            log.debug("Register system   ", fullname)
            r = {}
            w._class.system[fullname] = r
            importor.system(fullname)
        end
        return r
    end
    function ecs.component(fullname)
        local r = w._class.component[fullname]
        if r == nil then
            log.debug("Register component", fullname)
            r = {}
            w._class.component[fullname] = r
            importor.component(fullname)
        end
        return r
    end
    function ecs.require(fullname)
        local pkg, file = splitname(fullname)
        if not pkg then
            pkg = package
            file = fullname
        end
        return w._ecs[pkg].require_ecs(file)
    end
    local env = pm.loadenv(package)
    local _ECS_LOADED = {}
    local _ECS_LOADING = {}
    local function require_load(name)
        local searcher_lua = env.package.searchers[2]
        local f = searcher_lua(name)
        if type(f) == 'function' then
            return f
        end
        error(("module '%s' not found:\n\t%s"):format(name, f))
    end
    function ecs.require_ecs(file)
        assert(type(file) == "string", ("bad argument #1 to 'require' (string expected, got %s)"):format(type(file)))
        local p = _ECS_LOADED[file]
        if p ~= nil then
            return p
        end
        if _ECS_LOADING[file] then
            error(("Recursive load module '%s'"):format(file))
        end
        _ECS_LOADING[file] = true
        local initfunc = require_load(file)
        debug.setupvalue(initfunc, 1, env)
        local r = initfunc(ecs)
        if r == nil then
            r = true
        end
        _ECS_LOADED[file] = r
        _ECS_LOADING[file] = nil
        return r
    end
    function ecs.include_ecs(file)
        assert(type(file) == "string", ("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = _ECS_LOADED[file]
        if p ~= nil then
            return
        end
        if _ECS_LOADING[file] then
            return
        end
        _ECS_LOADING[file] = true
        local initfunc = require_load(file)
        debug.setupvalue(initfunc, 1, env)
        local r = initfunc(ecs)
        if r == nil then
            r = true
        end
        _ECS_LOADED[file] = r
        _ECS_LOADING[file] = nil
    end
    function ecs.clibs(name)
        return w:clibs(name)
    end
    w._ecs[package] = ecs
    return ecs
end

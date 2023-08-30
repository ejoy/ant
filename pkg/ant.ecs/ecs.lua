local pm = require "packagemanager"

local function sourceinfo()
	local info = debug.getinfo(3, "Sl")
	return string.format("%s(%d)", info.source, info.currentline)
end

local function keys(tbl)
	local k = {}
	for _, v in ipairs(tbl) do
		k[v] = true
	end
	return k
end

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
end

return function (w, package)
    local ecs = { world = w }
    local declaration = w._decl
    local import = w._importor
    local function register(what)
        ecs[what] = function(name)
            local fullname = name
            if what ~= "component" then
                fullname = package .. "|" .. name
            end
            local r = w._class[what][fullname]
            if r == nil then
                log.debug("Register", #what<8 and what.."  " or what, fullname)
                r = {}
                local decl = declaration[what][fullname]
                if not decl then
                    error(("%s `%s` has no declaration."):format(what, fullname))
                end
                if not decl.method then
                    error(("%s `%s` has no method."):format(what, fullname))
                end
                decl.source = {}
                decl.defined = sourceinfo()
                import[what](fullname)
                local callback = keys(decl.method)
                local object = {}
                w._class[what][fullname] = object
                setmetatable(r, {
                    __pairs = function ()
                        return pairs(object)
                    end,
                    __index = object,
                    __newindex = function(_, key, func)
                        if type(func) ~= "function" then
                            error(decl.defined..":Method should be a function")
                        end
                        if callback[key] == nil then
                            error(decl.defined..":Invalid callback function " .. key)
                        end
                        if decl.source[key] ~= nil then
                            error(decl.defined..":Method " .. key .. " has already defined at " .. decl.source[key])
                        end
                        decl.source[key] = sourceinfo()
                        object[key] = func
                    end,
                })
            end
            return r
        end
    end
    register "system"
    register "component"
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

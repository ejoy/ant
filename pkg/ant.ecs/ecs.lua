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
        local class_set = {}
        ecs[what] = function(name)
            local fullname = name
            if what ~= "component" then
                fullname = package .. "|" .. name
            end
            local r = class_set[fullname]
            if r == nil then
                log.debug("Register", #what<8 and what.."  " or what, fullname)
                r = {}
                class_set[fullname] = r
                local decl = declaration[what][fullname]
                if not decl then
                    error(("%s `%s` has no declaration."):format(what, fullname))
                end
                if not decl.method then
                    error(("%s `%s` has no method."):format(what, fullname))
                end
                decl.source = {}
                decl.defined = sourceinfo()
                local callback = keys(decl.method)
                local object = import[what](fullname)
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
    local _ECS_LOADED = {}
    local _ECS_LOADING = {}
    local function require_load(env, name)
        local msg = ''
		local searcher_lua = env.package.searchers[2]
		local f, extra = searcher_lua(name)
		if type(f) == 'function' then
			return f, extra, 1
		elseif type(f) == 'string' then
			msg = "\n\t" .. f
		end
        error(("module '%s' not found:%s"):format(name, msg))
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
		local env = pm.loadenv(package)
        local initfunc = require_load(env, file)
        debug.setupvalue(initfunc, 1, env)
        local r = initfunc(w._ecs[package])
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
		local env = pm.loadenv(package)
        local initfunc = require_load(env, file)
        debug.setupvalue(initfunc, 1, env)
        local r = initfunc(w._ecs[package])
        if r == nil then
            r = true
        end
        _ECS_LOADED[file] = r
        _ECS_LOADING[file] = nil
	end
    function ecs.create_entity(v)
        return w:_create_entity(nil, v)
    end
    function ecs.release_cache(v)
        return w:_release_cache(v)
    end
    function ecs.create_instance(v, parent)
        return w:_create_instance(nil, parent, v)
    end
    function ecs.group(id)
        return w:_create_group(id)
    end
    function ecs.group_flush(tag)
        return w:_group_flush(tag)
    end
    function ecs.clibs(name)
        return w:clibs(name)
    end
    w._ecs[package] = ecs
    return ecs
end

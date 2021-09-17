local pm = require "packagemanager"
pm.detect()

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

local OBJECT = {"system","policy","policy_v2","transform","interface","component","component_v2","pipeline","action"}

local function solve_object(o, w, what, fullname)
	local decl = w._decl[what][fullname]
	if decl and decl.method then
		for _, name in ipairs(decl.method) do
			if not o[name] then
				error(("`%s`'s `%s` method is not defined."):format(fullname, name))
			end
		end
	end
end

return function (w, package)
    local ecs = { world = w, method = w._set_methods }
    local declaration = w._decl
    local import = w._import
    local function register(what)
        local class_set = {}
        ecs[what] = function(name)
            local fullname = name
            if what ~= "action" and what ~= "component" then
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
                local object = import[what](package, fullname)
                setmetatable(r, {
                    __pairs = function ()
                        return pairs(object)
                    end,
                    __index = object,
                    __newindex = function(_, key, func)
                        if type(func) ~= "function" then
                            error("Method should be a function")
                        end
                        if callback[key] == nil then
                            error("Invalid callback function " .. key)
                        end
                        if decl.source[key] ~= nil then
                            error("Method " .. key .. " has already defined at " .. decl.source[key])
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
    register "transform"
    register "interface"
    register "action"
    register "component"
    function ecs.require(fullname)
        local pkg, file = splitname(fullname)
        if not pkg then
            pkg = package
            file = fullname
        end
        return pm.findenv(package, pkg)
            .require_ecs(w._ecs[pkg], file)
    end
    ecs.import = {}
    for _, objname in ipairs(OBJECT) do
        ecs.import[objname] = function (name)
            local res = rawget(w._class[objname], name)
            if res then
                return res
            end
            res = import[objname](package, name)
            if res then
                solve_object(res, w, objname, name)
            end
            return res
        end
    end
    w._ecs[package] = ecs
    return ecs
end

local GeneralTable = {}
local function GeneralFunction()
    return GeneralTable
end
setmetatable(GeneralTable, {
	__newindex = function() end,
	__index = GeneralFunction,
	__call = GeneralFunction,
	__div = GeneralFunction,
	__mul = GeneralFunction,
	__unm = GeneralFunction,
})

local world = GeneralTable
local env = setmetatable({
	import_package = GeneralFunction,
	require = GeneralFunction,
}, {__index = _G})

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

local function gen_set(c, setter)
	local keys = keys(setter)
	return function(_, key)
		if not keys[key] then
			error("Invalid set " .. key)
		end
		return function(value)
			local list = c[key]
			if list == nil then
				list = { value }
				c[key] = list
			else
				table.insert(list, value)
			end
		end
	end
end

local function gen_method(c, callback)
	if callback then
		callback = keys(callback)
	end
	return function(_, key, func)
		if type(func) ~= "function" then
			error("Method should be a function")
		end
		if callback and callback[key] == nil then
			error("Invalid callback function " .. key)
		end
		if c.source[key] ~= nil then
			error("Method " .. key .. " has already defined at " .. c.source[key])
		end
		c.source[key] = sourceinfo()
		rawset(c.method, key, func)
	end
end

local function tableAt(t, k)
	local v = t[k]
	if v then
		return v
	end
	v = {}
	t[k] = v
	return v
end

local function dyntable()
	return setmetatable({}, {__index=function(t,k)
		local o = {}
		t[k] = o
		return o
	end})
end

local current_package = ""
local function getCurrentPackage()
	return current_package
end

local log = { info = print }

local function typeclass(w)
    local createschema = require "packages.ecs.schema"
	local schema_data = {}
	local schema = createschema(schema_data)
	local class = { component = schema_data.map, singleton = {}, pipeline = {}, import = {} }
	local ecs = { world = w }

	local function register(args)
		local what = args.type
		local class_set = {}
		local class_data = class[what] or dyntable()
		class[what] = class_data
		ecs[what] = function(name)
			local package = getCurrentPackage()
			local r = tableAt(class_set, package)[name]
			if r == nil then
				--log.info("Register", #what<8 and what.."  " or what, package .. "|" .. name)
				local c = { name = name, method = {}, source = {}, defined = sourceinfo(), package = package }
				class_data[package][name] = c
				r = {}
				setmetatable(r, {
					__index = args.setter and gen_set(c, args.setter),
					__newindex = gen_method(c, args.callback),
				})
				tableAt(class_set, package)[name] = r
			end
			return r
		end
	end
	register {
		type = "system",
		setter = { "require_policy", "require_system", "require_singleton", "require_interface" },
	}
	register {
		type = "transform",
		setter = { "input", "output", "require_interface" },
		callback = { "process" },
	}
	register {
		type = "policy",
		setter = { "require_component", "require_transform", "require_system", "require_policy", "unique_component" },
		callback = { },
	}
	register {
		type = "interface",
		setter = { "require_system", "require_interface" },
	}
	ecs.component = function (name)
		return schema:type(getCurrentPackage(), name)
	end
	ecs.component_alias = function (name, ...)
		return schema:typedef(getCurrentPackage(), name, ...)
	end
	ecs.resource_component = function (name)
		local c = ecs.component_alias(name, "string")
		c._object.resource = true
		return c
	end
	ecs.tag = function (name)
		ecs.component_alias(name, "tag")
	end
	ecs.singleton = function (name)
		return function (dataset)
			if class.singleton[name] then
				error(("singleton `%s` duplicate definition"):format(name))
			end
			class.singleton[name] = {dataset}
		end
	end
	ecs.pipeline = function (name)
		local r = class.pipeline[name]
		if r == nil then
			--log.info("Register", "pipeline", name)
			r = {name = name}
			setmetatable(r, {
				__call = function(_,v)
					if r.value then
						error(("duplicate pipleline `%s`."):format(name))
					end
					r.value = v
					return r
				end,
			})
			class.pipeline[name] = r
		end
		return r
	end
	ecs.import = function(name)
		class.import[#class.import+1] = name
	end
    return ecs, class
end

return function (filename)
    local ecs, class = typeclass(world)
    local module = assert(loadfile(filename, 't', env))
    module(ecs)
    return class
end

local createschema = require "schema"

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

local function decl_basetype(schema)
	schema:primtype("ant.ecs", "tag", "boolean", true)
	schema:primtype("ant.ecs", "entityid", -1)
	schema:primtype("ant.ecs", "int", 0)
	schema:primtype("ant.ecs", "real", 0.0)
	schema:primtype("ant.ecs", "string", "")
	schema:primtype("ant.ecs", "boolean", false)
end

local function singleton_solve(w)
	local class = w._class
	for name in pairs(class.singleton) do
		local ti = class.component[name]
		if not ti then
			error(("singleton `%s` is not defined in component"):format(name))
		end
		if not ti.type and ti.multiple then
			error(("singleton `%s` does not support multiple component"):format(name))
		end
		if class.unique[name] then
			error(("singleton `%s` does not support unique component"):format(name))
		end
		class.unique[name] = true
	end
end

local function interface_solve(w)
	local class = w._class
	local interface = w._interface
	for package, o in pairs(class.interface) do
		for name, v in pairs(o) do
			interface[package.."|"..name] = setmetatable({}, {__index = v.method})
		end
	end
end

local current_package = {}
local function resetCurrentPackage()
	current_package = {}
end

local function getCurrentPackage()
	return current_package[#current_package]
end
local function pushCurrentPackage(name)
	current_package[#current_package+1] = name
end
local function popCurrentPackage()
	current_package[#current_package] = nil
end
local deferCurrentPackage = setmetatable({}, {__close=popCurrentPackage})

local function tableAt(t, k)
	local v = t[k]
	if v then
		return v
	end
	v = {}
	t[k] = v
	return v
end

local function importAll(w, ecs, class, config, loader)
	local cut = {
		policy = {},
		system = {},
		transform = {},
		singleton = {},
		interface = {},
		component = class.component,
		unique = {},
	}
	w._class = cut
	local policies = config.policy
	local systems  = config.system
	local imported = {}
	local importPolicy
	local importSystem
	local importComponent
	local importTransform
	local importSingleton
	local importInterface
	local function importPackage(name)
		if imported[name] then
			return
		end
		imported[name] = true
		local modules = assert(loader(name) , "load module " .. name .. " failed")
		if type(modules) == "table" then
			for _, m in ipairs(modules) do
				m(ecs)
			end
		else
			modules(ecs)
		end
	end
	local function splitName(fullname)
		local package, name = fullname:match "^([^|]*)|(.*)$"
		if package then
			pushCurrentPackage(package)
			importPackage(package)
			return package, name, deferCurrentPackage
		end
		return getCurrentPackage(), fullname
	end
	ecs.import = function(name)
		pushCurrentPackage(name)
		importPackage(name)
		popCurrentPackage()
	end
	function importPolicy(k)
		local package, name, defer <close> = splitName(k)
		if tableAt(cut.policy, package)[name] then
			return
		end
		local v = class.policy[package][name]
		if not v then
			error(("invalid policy name: `%s`."):format(name))
		end
		tableAt(cut.policy, package)[name] = v
		if v.require_system then
			for _, k in ipairs(v.require_system) do
				importSystem(k)
			end
		end
		if v.require_policy then
			for _, k in ipairs(v.require_policy) do
				importPolicy(k)
			end
		end
		if v.require_transform then
			for _, k in ipairs(v.require_transform) do
				importTransform(k)
			end
		end
		if v.require_component then
			for _, k in ipairs(v.require_component) do
				importComponent(k)
			end
		end
		if v.unique_component then
			for _, k in ipairs(v.unique_component) do
				importComponent(k)
				cut.unique[k] = true
			end
		end
	end
	function importSystem(k)
		local package, name, defer <close> = splitName(k)
		if tableAt(cut.system, package)[name] then
			return
		end
		local v = class.system[package][name]
		if not v then
			error(("invalid system name: `%s`."):format(name))
		end
		tableAt(cut.system, package)[name] = v
		if v.require_system then
			for _, k in ipairs(v.require_system) do
				importSystem(k)
			end
		end
		if v.require_policy then
			for _, k in ipairs(v.require_policy) do
				importPolicy(k)
			end
		end
		if v.require_singleton then
			for _, k in ipairs(v.require_singleton) do
				importSingleton(k)
			end
		end
		if v.require_interface then
			for _, k in ipairs(v.require_interface) do
				importInterface(k)
			end
		end
	end
	function importComponent(k)
		--TODO
		--local package, name, defer <close> = splitName(k)
		--if tableAt(cut.component, package)[name] then
		--	return
		--end
		--local v = class.component[name]
		--if not v then
		--	error(("invalid component name: `%s`."):format(name))
		--end
		--tableAt(cut.component, package)[name] = v
	end
	function importTransform(k)
		local package, name, defer <close> = splitName(k)
		if tableAt(cut.transform, package)[name] then
			return
		end
		local v = class.transform[package][name]
		if not v then
			error(("invalid transform name: `%s`."):format(name))
		end
		tableAt(cut.transform, package)[name] = v
		if v.input then
			for _, k in ipairs(v.input) do
				importComponent(k)
			end
		end
		if v.output then
			for _, k in ipairs(v.output) do
				importComponent(k)
			end
		end
	end
	function importSingleton(k)
		local name = k
		if cut.singleton[name] then
			return
		end
		local v = class.singleton[name]
		if not v then
			error(("invalid singleton name: `%s`."):format(name))
		end
		cut.singleton[name] = v
	end
	function importInterface(k)
		local package, name, defer <close> = splitName(k)
		if tableAt(cut.interface, package)[name] then
			return
		end
		local v = class.interface[package][name]
		if not v then
			error(("invalid interface name: `%s`."):format(name))
		end
		tableAt(cut.interface, package)[name] = v
	end
	resetCurrentPackage()
	for _, k in ipairs(policies) do
		importPolicy(k)
	end
	for _, k in ipairs(systems) do
		importSystem(k)
	end
	return cut
end

local function dyntable()
	return setmetatable({}, {__index=function(t,k)
		local o = {}
		t[k] = o
		return o
	end})
end

return function (w, config, loader)
	local schema_data = {}
	local schema = createschema(schema_data)
	local class = { component = schema_data.map, singleton = {} }
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
				log.info("Register", what, package .. "|" .. name)
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
		setter = { "input", "output" },
		callback = { "process" },
	}
	register {
		type = "policy",
		setter = { "require_component", "require_transform", "require_system", "require_policy", "unique_component" },
		callback = { },
	}
	register {
		type = "interface",
	}
	ecs.component = function (name)
		return schema:type(getCurrentPackage(), name)
	end
	ecs.component_alias = function (name, ...)
		return schema:typedef(getCurrentPackage(), name, ...)
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
	decl_basetype(schema)
	importAll(w, ecs, class, config, loader)
	require "component".solve(schema_data)
	require "policy".solve(w)
	singleton_solve(w)
	interface_solve(w)
end

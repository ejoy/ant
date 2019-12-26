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

local function decl_basetype(class_register)
	class_register.component_alias("tag", "boolean", true)
	class_register.component_base("entityid", -1)

	class_register.component_base("int", 0)
	class_register.component_base("real", 0.0)
	class_register.component_base("string", "")
	class_register.component_base("boolean", false)
end

return function(world, import, class)
	local schema = createschema(world._schema)
	local class_register = { world = world, import = import }
	local class = class or {}
	class.component = world._schema.map

	local function register(args)
		local what = args.type
		local class_set = {}
		local class_data = class[what] or {}
		class[what] = class_data
		class_register[what] = function(name)
			local r = class_set[name]
			if r == nil then
				log.info("Register", what, name)
				local c = { name = name, method = {}, source = {}, defined = sourceinfo() }
				class_data[name] = c
				r = {}
				setmetatable(r, {
					__index = args.setter and gen_set(c, args.setter),
					__newindex = gen_method(c),
				})

				class_set[name] = r
			end
			return r
		end
	end

	register {
		type = "singleton",
		callback = { "init" },
	}

	register {
		type = "system",
		setter = { "depend", "dependby", "singleton" },
	}

	register {
		type = "transform",
		setter = { "input", "output" },
		callback = { "process" },
	}

	register {
		type = "policy",
		setter = { "require_component", "require_transform" },
	}

	class.packages = {}

	class_register.component = function (name)
		return schema:type(class.packages[1], name)
	end

	class_register.component_alias = function (name, ...)
		return schema:typedef(class.packages[1], name, ...)
	end
	
	class_register.component_base = function (name, ...)
		schema:primtype(class.packages[1], name, ...)
	end

	class.mark_handlers = {}
	class_register.mark = function(name, handler)
		--class_register.tag(name)
		class.mark_handlers[name] = handler
	end

	decl_basetype(class_register)
	class_register.tag = function (name)
		class_register.component_alias(name, "tag")
	end

	return class_register, class
end

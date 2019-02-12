local log = log and log(...) or print

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

return function(world, import, class)
	local class_register = { world = world }
	local class = class or {}

	local function register(args)
		local what = args.type
		local class_set = {}
		local class_data = class[what] or {}
		class[what] = class_data
		class_register[what] = function(name)
			local r = class_set[name]
			if r == nil then
				log("Register %s %s", what, name)
				local c = { name = name, method = {}, source = {}, defined = sourceinfo() }
				class_data[name] = c
				r = {}
				if args.submethod then
					for _, subm in ipairs(args.submethod) do
						local sub = { source = {}, method = {} }
						c[subm] = sub.method
						r[subm] = setmetatable({}, { __newindex = gen_method(sub) })
					end
				end
				setmetatable(r, {
					__index = args.setter and gen_set(c, args.setter),
					__newindex = gen_method(c, args.callback),
				})

				class_set[name] = r
			end
			return r
		end
	end

	register {
		type = "singleton_component",
		callback = { "init" },
	}

	register {
		type = "system",
		setter = { "depend" , "dependby", "singleton" },
		submethod = { "notify" },
		callback = { "init", "update" },
	}

	local schema = world.schema
	class_register.tag = function (name)
		schema:typedef(name, "tag")
	end

	class_register.component = function (name)
		assert(schema.map[name])
		local c = schema.map[name]
		if not c.method then
			c.source = {}
			c.method = setmetatable({}, {
				__newindex = gen_method(c, {"init", "delete", "save", "postsave"}),
			})
		end
		return c.method
	end

	class_register.import = import

	return class_register, class
end

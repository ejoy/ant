local require = import and import(...) or require
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
		c.method[key] = func
	end
end

local function gen_type(c, typename)
	return function(self, struct)
		if type(struct) ~= "table" then
			error("Type struct should be a table")
		end
		if c.struct_source ~= nil then
			error("Type struct has already defined at " .. c.struct_source)
		end
		c.struct_source = sourceinfo()
		c[typename] = struct
		return self
	end
end

return function(world, import)
	local class_register = { world = world }
	local class = {}

	local function register(args)
		local what = args.type
		local class_set = {}
		local class_data = {}
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
					__call = args.typename and gen_type(c, args.typename),
				})

				class_set[name] = r
			end
			return r
		end
	end

	register {
		type = "component",
		typename = "struct",
	}
	register {
		type = "system",
		setter = { "depend" , "dependby", "singleton", "import" },
		submethod = { "notify" },
		callback = { "init", "update" },
	}

	class_register.tag = function (name)
		local c = class_register.component(name)
		c.new = function() return true end

		return function (content)
			if content and (type(content) ~= "table" or next(content)) then
				error("tag component should not add any member")
			end
		end
	end

	class_register.component_struct = function (name)
		local c = class_register.component(name)
		return function (content)
			return c {
				struct = content
			}
		end
	end

	class_register.import = import

	return class_register, class
end

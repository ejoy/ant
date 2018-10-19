local require = import and import(...) or require
local log = log and log(...) or print

local datatype = require "datatype"

local function gen_new(c)
	if c.struct then
		if c.method.new then
			error(string.format("Type %s defined at %s has a struct. It defines new at %s, use init instead",
				c.name, c.defined, c.source.new))
		end
		local init = c.method.init
		return function()
			local ret
			if c.struct.struct then
				ret = {}
				for k,v in pairs(c.struct.struct) do
					local default = v.default
					if default ~= nil then
						ret[k] = default
					else
						ret[k] = v.default_func()
					end
				end
			else
				local v = c.struct
				local default = v.default
				if default ~= nil then
					ret = default
				else
					ret = v.default_func()
				end
			end
			if init then
				init(ret)
			end
			return ret
		end
	else
		-- user type
		local new = c.method.new
		if new == nil then
			error(string.format("Type %s defined at %s has no struct without new",
				c.name, c.defined))
		end
		if c.method.init then
			error(string.format("Usertype %s defined at %s defines new at %s, init at %s has no effect",
				c.name, c.defined, c.source.new, c.source.init))
		end
		return new
	end
end

local reserved_method = { new = true, init = true, delete = true }

local function copy_method(c)
	local methods = c.method
	local m = {}
	if methods then
		local cname = c.name
		for name, f in pairs(methods) do
			if not reserved_method[name] then
				m[cname .. "_" .. name] = function(entity, ...)
					return f(entity[cname], ...)
				end
			end
		end
	end
	return m
end

local function gen_save(struct)
	if struct and struct.struct then
		return function (c, arg)
			assert(type(c) == "table")
			local t = {}
			for k, v in pairs(c) do
				local vclass = struct[k]
				if vclass then
					arg.struct_type = k
					local save = vclass.save
					t[k] = save(v, arg)
				end
			end
			return t
		end
	elseif struct and struct.type == "tag" then
		return function (c, arg)
			-- this is tag
			assert(type(c) == "boolean")
			return c
		end
	else
		return function (v, arg)
			arg.struct_type = "" --TODO
			local save = struct.save
			return save(v, arg)
		end
	end
end

local function gen_load(struct)
	if struct and struct.struct then
		return function(c, v, arg)
			local keys = {}
			for k in pairs(c) do
				table.insert(keys, k)
			end

			for _, k in ipairs(keys) do
				local vclass = struct[k]
				if vclass then
					arg.struct_type = k
					local load = vclass.load
					c[k] = load(v[k], arg)
				end
			end
		end
	else
		return function(c, v, arg)
			arg.struct_type = "" -- TODO
			local load = struct.load
			c = load(v, arg)
		end
	end
end

return function(c)
	local struct = c.struct and datatype(c)
	return {
		struct = struct,
		new = gen_new(c),
		save = gen_save(struct),
		load = gen_load(struct),
		delete = c.method.delete,
		method = copy_method(c),
	}
end

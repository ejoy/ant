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
			local ret = {}
			for k,v in pairs(c.struct) do
				local default = v.default
				if default ~= nil then
					ret[k] = default
				else
					ret[k] = v.default_func()
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

local function gen_delete(c)
	local primitive
	if c.struct then
		-- matrix and vector
		for k,v in pairs(c.struct) do
			local tname = v.type
			if tname == "matrix" or tname == "vector" then
				local last = primitive
				if last then
					function primitive(component)
						component[k] = nil
						return last(component)
					end
				else
					function primitive(component)
						component[k] = nil
					end
				end
			end
		end
	end
	local delete = c.method.delete
	if delete then
		if primitive then
			return function(component)
				delete(component)
				primitive(component)
			end
		else
			return delete
		end
	else
		return primitive
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
	return function (c)
		local t = {}
		for k, v in pairs(c) do
			local vclass = struct[k]
			if vclass then
				local save = vclass.save
				t[k] = save(v)
			end
		end
		return t
	end
end

local function gen_load(struct)	
	return function(c, v)		
		for k, _ in pairs(c) do
			local load = struct[k].load
			c[k] = load(v)
		end
	end
end

return function(c)
	local struct = c.struct and datatype(c.struct)
	return {
		struct = struct,
		new = gen_new(c),
		save = gen_save(struct),
		load = gen_load(struct),
		delete = gen_delete(c),
		method = copy_method(c),
	}
end

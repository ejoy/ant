local datatype = require "datatype"

local function gen_new(c)
	if c.method.new then
		error(string.format("Type %s defined at %s has a typeinfo. It defines new at %s, use init instead",
			c.name, c.defined, c.source.new))
	end
	local init = c.method.init
	return function()
		local ret
		if c.typeinfo.struct then
			ret = {}
			for k,v in pairs(c.typeinfo.struct) do
				local default = v.default
				if default ~= nil then
					ret[k] = default
				else
					ret[k] = v.default_func()
				end
			end
		else
			local v = c.typeinfo
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
end

local function gen_delete(c)
	local primitive
	-- matrix and vector
	if c.typeinfo.struct then
		for k,v in pairs(c.typeinfo) do
			local tname = v.type
			if tname == "matrix" or tname == "vector" then
				local last = primitive
				if last then
					function primitive(component)
						component[k]()  -- release ref
						return last(component)
					end
				else
					function primitive(component)
						component[k]()  -- release ref
					end
				end
			end
		end
	else
		local v = c.typeinfo
		local tname = v.type
		if tname == "matrix" or tname == "vector" then
			function primitive(component)
				component()  -- release ref
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

local function gen_save(typeinfo)
	if typeinfo and typeinfo.struct then
		return function (c, arg)
			assert(type(c) == "table")
			local t = {}
			for k, v in pairs(c) do
				local vclass = typeinfo[k]
				if vclass then
					arg.struct_type = k
					local save = vclass.save
					t[k] = save(v, arg)
				end
			end
			return t
		end
	else
		return function (c, arg)
			--TODO
			return c
		end
	end
end

local function gen_load(typeinfo)
	if typeinfo and typeinfo.struct then
		return function(v, arg)
			local c = {}
			local keys = {}
			for k in pairs(c) do
				table.insert(keys, k)
			end

			for _, k in ipairs(keys) do
				local vclass = typeinfo[k]
				if vclass then
					arg.struct_type = k
					local load = vclass.load
					c[k] = load(v[k], arg)
				end
			end
			return c
		end
	else
		return function(v, arg)
			-- TODO
			return v
		end
	end
end

return function(c)
	local typeinfo = datatype(c)
	return {
		typeinfo = typeinfo,
		new = gen_new(c),
		save = gen_save(typeinfo),
		load = gen_load(typeinfo),
		delete = gen_delete(c),
		method = copy_method(c),
	}
end

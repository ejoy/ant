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
		return new
	end
end

local reserved_method = { new = true, init = true }

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

return function(c)
	return {
		struct = c.struct and datatype(c.struct),
		new = gen_new(c),
		method = copy_method(c),
	}
end

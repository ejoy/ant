local require = import and import(...) or require
local log = log and log(...) or print

local datatype = require "datatype"

local function gen_new(c)
	local new = c.method.new
	if c.struct then
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
			if new then
				new(ret)
			end
			return ret
		end
	else
		-- c type
		return new
	end
end

local reserved_method = { new = true }

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
		struct = datatype(c.struct),
		new = gen_new(c),
		method = copy_method(c),
	}
end

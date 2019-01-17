local function deep_copy(obj)
	if type(obj) ~= "table" then
		return obj
	end
	local t = {}
	for k, v in pairs(obj) do
		t[k] = deep_copy(v)
	end
	return t
end

local function foreach_init(ti)
	if type(ti) ~= 'table' then
		return ti
	elseif ti.__type then
		return ti.init()
	else
		local ret = {}
		for k, v in pairs(ti) do
			ret[k] = foreach_init(v)
		end
		return ret
	end
end

local function gen_init(c)
	if not c.method.init then
		return function()
			return foreach_init(c.typeinfo)
		end
	end
	local init = c.method.init
	return function()
		local ret = foreach_init(c.typeinfo)
		init(ret)
		return ret
	end
end

local function foreach_delete(ti, component)
	if type(ti) ~= 'table' then
	elseif ti.__type then
		return ti.delete
	else
		for k, v in pairs(ti) do
			local df = foreach_delete(v, component[k])
			if df then
				df(component[k])
			end
		end
	end
end

local function gen_delete(c)
	local function primitive(component)
		local df = foreach_delete(c.typeinfo, component)
		if df then
			df(component)
		end
	end

	local delete = c.method.delete
	if delete then
		return function(component)
			delete(component)
			primitive(component)
		end
	else
		return primitive
	end
end

local function foreach_save(ti, component, arg)
	if type(ti) ~= 'table' then
		return component
	elseif ti.__type then
		return ti.save(component, arg)
	else
		local ret = {}
		for k, v in pairs(ti) do
			ret[k] = foreach_save(v, component[k], arg)
		end
		return ret
	end
end

local function gen_save(c)
	local save = c.method.save
	if save then
		return function (component, arg)
			return save(foreach_save(c.typeinfo, component, arg), arg)
		end
	else
		return function (component, arg)
			return foreach_save(c.typeinfo, component, arg)
		end
	end
end

local function foreach_load(ti, component, arg)
	if type(ti) ~= 'table' then
		return component
	elseif ti.__type then
		return ti.load(component, arg)
	else
		local ret = {}
		for k, v in pairs(ti) do
			ret[k] = foreach_load(v, component[k], arg)
		end
		return ret
	end
end

local function gen_load(c)
	local load = c.method.load
	if load then
		return function (component, arg)
			return load(foreach_load(c.typeinfo, component, arg), arg)
		end
	else
		return function (component, arg)
			return foreach_load(c.typeinfo, component, arg)
		end
	end
end

local reserved_method = { init = true, delete = true, save = true, load = true }

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
	local typeinfo = c.typeinfo
	return {
		typeinfo = typeinfo,
		init = gen_init(c),
		save = gen_save(c),
		load = gen_load(c),
		delete = gen_delete(c),
		method = copy_method(c),
	}
end

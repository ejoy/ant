local callback = {init=true, delete=true, save=true}
local fields_mt = {}
local defaults_mt = {}
function defaults_mt:__call()
	return setmetatable(self, fields_mt)
end
function defaults_mt:__index()
	return setmetatable(self, fields_mt)
end
function fields_mt:__index()
	return self
end
function fields_mt:__call()
	return setmetatable(self, defaults_mt)
end
function fields_mt:__newindex(key, func)
	assert(type(key) == "string")
	if type(func) ~= "function" then
		error("Method should be a function")
	end
	if callback[key] == nil then
		error("Invalid callback function " .. key)
	end
	local obj = self._schema[self._name]
	if not obj then
		obj = {}
		self._schema[self._name] = obj
	end
	obj.methodfunc = obj.methodfunc or {}
	obj.methodfunc[key] = func
end
defaults_mt.__newindex = fields_mt.__newindex
return function (class)
	return function (typename)
		return setmetatable({ _schema = class, _name = typename }, fields_mt)
	end
end

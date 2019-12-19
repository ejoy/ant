local fields_mt = {}
local defaults_mt = {}

function defaults_mt:__call(default_value)
	-- todo: check type
	local field = self._object[#self._object]
	if field.array then
		assert(type(default_value) == "table")
		assert(field.array == 0 or #default_value == field.array , "Invalid array defaults")
		for k,v in ipairs(default_value) do
			default_value[k] = v
		end
	elseif field.map then
		assert(type(default_value) == "table")
		for k,v in pairs(default_value) do
			assert(type(k) == "string")
			default_value[k] = v
		end
	end
	field.has_default = true
	field.default = default_value
	rawset(self, "_current_field", {})
	return setmetatable(self, fields_mt)
end

function defaults_mt:__index(name)
	rawset(self, "_current_field", {})
	fields_mt.__index(self, name)
	return setmetatable(self, fields_mt)
end

function fields_mt:__index(name)
	assert(type(name) == "string")
	table.insert(self._current_field, name)
	self._object.uncomplete = true
	return self
end

local callback = {init=true, delete=true, save=true, postsave=true}

function fields_mt:__newindex(key, func)
	assert(type(key) == "string")
	if type(func) ~= "function" then
		error("Method should be a function")
	end
	if callback[key] == nil then
		error("Invalid callback function " .. key)
	end
	local obj = self._schema.map[self._name]
	obj.method = obj.method or {}
	obj.method[key] = func
end

defaults_mt.__newindex = fields_mt.__newindex

local function checktype(self, typename, name)
	if self.map[typename] then
		return
	end
	self._undefined[typename] = name
end

local function parse_type(t)
	local typename = t.type
	local name, array = typename:match "(%S+)%[(%d*)%]"	-- array pattern : type[1]
	if name == nil then
		local name, map = typename:match "(%S+){}"	-- map pattern : type{}
		if name then
			t.type = name
			t.map = true
		end
	else
		if array == "" then
			array = 0
		else
			array = tonumber(array)
		end
		t.type = name
		t.array = array
	end
	return t
end

function fields_mt:__call(typename)
	if type(typename) == 'table' then
		local obj = self._schema.map[self._name]
		obj.multiple = typename.multiple
		return setmetatable(self, defaults_mt)
	end
	local attrib = self._current_field
	self._current_field = nil
	local field_n = #attrib
	assert(field_n > 0, "Need field name")
	local item = parse_type {
		name = attrib[field_n],
		type = typename,
	}
	checktype(self._schema, item.type, self._name)
	attrib[field_n] = nil
	assert(self._field[item.name] == nil)

	if field_n > 1 then
		local t = {}
		for _, v in ipairs(attrib) do
			t[v] = true
		end
		item.attrib = t
	end

	table.insert(self._object, item)

	self._object.uncomplete = nil

	return setmetatable(self, defaults_mt)
end

local function _newtype(self, typeobject)
	local typename = typeobject.name
	if self.map[typename] then
		return self.map[typename]
	end
	assert(self.map[typename] == nil)
	self.map[typename] = typeobject
	table.insert(self.list, typeobject)
	return typeobject
end

return function (class)
	class.list = class.list or {}
	class.map = class.map or {}
	class._undefined = class._undefined or {}

	local schema = {}

	function schema:type(package, typename)
		local typeobject = _newtype(class, {
			package = package,
			name = typename
		})
		local typegen = {
			_schema = class,
			_name = typename,
			_object = typeobject,
			_current_field = {},
			_field = {},
		}
		return setmetatable(typegen, fields_mt)
	end

	function schema:typedef(package, typename, aliastype, ...)
		local typeobject = _newtype(class, parse_type {
			package = package,
			name = typename,
			type = aliastype,
			has_default = select('#', ...) > 0,
			default = select('1', ...),
		} )
		local typegen = {
			_schema = class,
			_name = typename,
			_object = typeobject,
			_current_field = {},
			_field = {},
		}
		return setmetatable(typegen, fields_mt)
	end

	function schema:primtype(package, typename, ...)
		_newtype(class, {
			package = package,
			name = typename,
			type = "primtype",
			has_default = select('#', ...) > 0,
			default = select('1', ...),
		})
	end

	return schema
end

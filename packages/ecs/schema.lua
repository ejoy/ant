--[[
schema.type "NAME"
	["temp"].a "int" (1)
	.b "OBJECT"
	.c [ "private" ] "mat" {}
	.d "texture"
	.array "int[4]" { 1,2,3,4 }
]]
local schema = {} ; schema.__index = schema

function schema.new()
	local s = {
		list = {},
		map = {},
		_undefined = {},
	}
	return setmetatable(s, schema)
end

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
	field.default = default_value
	self._current_field = {}
	return setmetatable(self, fields_mt)
end

function defaults_mt:__index(name)
	self._current_field = {}
	fields_mt.__index(self, name)
	return setmetatable(self, fields_mt)
end

function fields_mt:__index(name)
	assert(type(name) == "string")
	table.insert(self._current_field, name)
	self._object.uncomplete = true
	return self
end

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

function schema:_newtype(typeobject)
	local typename = typeobject.name
	assert(self.map[typename] == nil)
	self.map[typename] = typeobject
	table.insert(self.list, typeobject)
	return typeobject
end

function schema:type(typename)
	local typeobject = self:_newtype {
		name = typename
	}
	local typegen = {
		_schema = self,
		_name = typename,
		_object = typeobject,
		_current_field = {},
		_field = {},
	}
	return setmetatable(typegen, fields_mt)
end

function schema:typedef(typename, aliastype, default_value)
	self:_newtype( parse_type {
		name = typename,
		type = aliastype,
		default = default_value,
	} )
end

function schema:primtype(typename, default_value)
	self:_newtype {
		name = typename,
		type = "primtype",
		default = default_value,
	}
end

function schema:check()
	for k,v in ipairs(self.list) do
		if v.uncomplete then
			error( v.name .. " is uncomplete")
		end
	end
	for k,v in pairs(self._undefined) do
		if self.map[k] then
			self._undefined[k] = nil
		else
			error( k .. " is undefined in " .. self._undefined[k])
		end
	end
end

return schema

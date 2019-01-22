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
local basetype = {}

function defaults_mt:__call(default_value)
	-- todo: check type
	local field = self._object[#self._object]
	local cf = basetype[field.type]
	if cf then
		if field.array then
			assert(type(default_value) == "table")
			assert(field.array == 0 or #default_value == field.array , "Invalid array defaults")
			for k,v in ipairs(default_value) do
				local ok, v = assert(cf(v))
				default_value[k] = v
			end
		elseif field.map then
			assert(type(default_value) == "table")
			for k,v in pairs(default_value) do
				assert(type(k) == "string")
				local ok, v = assert(cf(v))
				default_value[k] = v
			end
		else
			local ok , v = assert(cf(default_value))
			default_value = v
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

function basetype.int(v)
	local c = math.tointeger(v)
	if c then
		return true, c
	end
	return false, tostring(v) .. " is not an integer"
end

function basetype.real(v)
	local c = tonumber(v)
	if c then
		return true, c
	end
	return false, tostring(v) .. " is not a number"
end

function basetype.string(v)
	if type(v) ~= "string" then
		return false, tostring(v) .. " is not a string"
	else
		return true, v
	end
end

function basetype.boolean(v)
	if type(v) ~= "boolean" then
		return false, tostring(v) .. " is not a boolean"
	else
		return true, v
	end
end

function basetype.var(v)
	return true, v
end

local function checktype(self, typename, name)
	if basetype[typename] or self.map[typename] then
		return
	end
	self._undefined[typename] = name
end

local function array_type(typename)
	local name, array = typename:match "(%S+)%[(%d*)%]"	-- array pattern : type[1]
	if name == nil then
		local name, map = typename:match "(%S+){}"	-- map pattern : type{}
		if name == nil then
			return typename
		else
			return name, true	-- It's a map
		end
	else
		if array == "" then
			array = 0
		else
			array = tonumber(array)
		end
		return name, array
	end
end

function fields_mt:__call(typename)
	local typename, array = array_type(typename)
	local map
	if array == true then
		array = nil
		map = true
	end
	local attrib = self._current_field
	self._current_field = nil
	local field_n = #attrib
	assert(field_n > 0, "Need field name")
	local item = {
		name = attrib[field_n],
		type = typename,
		array = array,
		map = map,
	}
	checktype(self._schema, typename, self._name)
	attrib[field_n] = nil
	assert(self._field[item.name] == nil)

	if field_n > 1 then
		item.attrib = attrib
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
	self:_newtype {
		name = typename,
		type = aliastype,
		default = default_value
	}
end

function schema:userdata(typename)
	self:_newtype {
		name = typename,
		type = "userdata",
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

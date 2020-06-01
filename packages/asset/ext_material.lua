local ecs = ...

local math3d = require "math3d"
local bgfx = require "bgfx"
local fs = require "filesystem"
local datalist = require "datalist"

local function uniform_data(v)
	local num = #v
	if num == 4 then
		return math3d.ref(math3d.vector(v))
	elseif num == 16 then
		return math3d.ref(math3d.matrix(v))
	elseif num == 0 then
		return math3d.ref()
	else
		error(string.format("invalid uniform data, only support 4/16 as vector/matrix:%d", num))
	end
end

local p = ecs.component "property"
function p:init()
	for i=1, #self do
		self[i] = uniform_data(self[i])
	end
	return self
end

function p:save()
	if self.stage == nil then
		local res = {}
		for i=1, #self do
			res[i] = math3d.tovalue(self[i])
		end
		return res
	end

	return self
end

local m = ecs.component "material"

local function load_state(filename)
	if type(filename) == "string" then
		local f = assert(fs.open(fs.path(filename), 'rb'))
		local data = f:read 'a'
		f:close()
		return datalist.parse(data)
	else
		return filename
	end
end

function m:init()
	assert(type(self.fx) ~= "string")
	self._state = bgfx.make_state(load_state(self.state))
	return self
end

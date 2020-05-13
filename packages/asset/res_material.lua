local ecs = ...

local math3d = require "math3d"

local m = ecs.component "uniform"

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

function m:init()
	for i = 1, #self do
		self[i] = uniform_data(self[i])
	end
	return self
end

function m:save()
    return math3d.totable(self)
end

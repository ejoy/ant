local ecs = ...
local world = ecs.world

local math3d_baselib = require "math3d.baselib"

local cull_sys = ecs.system "cull_system"
cull_sys.singleton "math_stack"
cull_sys.depend "primitive_filter_system"
cull_sys.dependby "lighting_primitive_filter_system"

function cull_sys:update()
	for _, eid in world:each("primitive_filter") do
		local e = world[eid]
		local filter = e.primitive_filter
		local frustum = assert(e.frustum)
		local newfilter_result = {}
		local results = filter.result
		for _, prim in ipairs(results) do
			local result = math3d_baselib.interset(frustum, prim.aabb)
			if result ~= "outside" then
				table.insert(newfilter_result, prim)
			end
		end

		if #newfilter_result ~= #results then
			filter.result = newfilter_result
		end
	end
end
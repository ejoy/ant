--luacheck: ignore self

local ecs = ...
local world = ecs.world

local math = import_package "ant.math"
local ms = math.stack

--- scene lighting fitler system ------------------------
local lighting_primitive_filter_sys = ecs.system "lighting_primitive_filter_system"

lighting_primitive_filter_sys.depend "primitive_filter_system"
lighting_primitive_filter_sys.dependby "final_filter_system"

function lighting_primitive_filter_sys:update()		
	for _, eid in world:each("primitive_filter") do
		local e = world[eid]		
		local filter = e.primitive_filter
		if not filter.no_lighting then
			append_lighting_properties(filter)
		end
	end
end
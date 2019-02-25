local ecs = ...
local world = ecs.world

local render = import_package "ant.render"
local cu = render.components
local ru = render.util

local ms = import_package "ant.math" .stack

local primitive_filter_sys = ecs.system "primitive_filter_system"

--luacheck: ignore self
function primitive_filter_sys:update()
	for _, prim_eid in world:each("primitive_filter") do
		local e = world[prim_eid]
		local filter = e.primitive_filter
		filter.idx = 1		
		for _, eid in world:each("can_render") do
			local ce = world[eid]
			if cu.is_entity_visible(ce) then
				if (not filter.filter_select) or ce.can_select then
					print("insert", eid)
					ru.insert_primitive(eid, 
						assert(ce.mesh.assetinfo).handle,
						assert(ce.material.content),
						ms({type="srt", s=ce.scale, r=ce.rotation, t=ce.position}, "m"),
						filter)
				end
			end
		end	
	end
end

-- all filter system need depend 
local final_filter_sys = ecs.system "final_filter_system"
final_filter_sys.depend "primitive_filter_system"
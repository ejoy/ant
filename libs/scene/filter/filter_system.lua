local ecs = ...
local world = ecs.world

--ecs.import "scene.shadow.generate_shadow_system"

local cu = require "render.components.util"

local ru = require "render.util"

local primitive_filter_sys = ecs.system "primitive_filter_system"

--luacheck: ignore self
function primitive_filter_sys:update()
	for _, eid in world:each("primitive_filter") do
		local e = world[eid]
		local filter = e.primitive_filter
		filter.result = {}		
		for _, eid in world:each("can_render") do
			local ce = world[eid]
			if cu.is_entity_visible(ce) then
				if (not filter.filter_select) or ce.can_select then					
					local meshhandle = assert(ce.mesh.assetinfo).handle
					local materials = assert(ce.material.content)
					
					ru.insert_primitive(eid, 
						meshhandle, 
						materials, 
						{s=ce.scale, r=ce.rotation, t=ce.position},
						filter.result)
				end
			end
		end
	end
end

-- all filter system need depend 
local final_filter_sys = ecs.system "final_filter_system"
final_filter_sys.depend "primitive_filter_system"
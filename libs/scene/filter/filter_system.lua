local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"
--ecs.import "scene.shadow.generate_shadow_system"

local cu = require "render.components.util"

local function insert_primitive(eid, result)
	local entity = world[eid]

	local mesh = assert(entity.mesh.assetinfo)
	
	local materialcontent = entity.material.content
	assert(#materialcontent >= 1)

	local srt ={s=entity.scale, r=entity.rotation, t=entity.position}
	local mgroups = mesh.handle.groups
	for i=1, #mgroups do
		local g = mgroups[i]
		local mc = materialcontent[i] or materialcontent[1]
		local material = mc.materialinfo
		local properties = mc.properties

		table.insert(result, {
			eid = eid,
			mgroup = g,
			material = material,
			properties = properties,
			srt = srt,
		})
	end
end

local primitive_filter_sys = ecs.system "primitive_filter_system"
primitive_filter_sys.singleton "math_stack"

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
					insert_primitive(eid, filter.result)
				end
			end
		end
	end
end

-- all filter system need depend 
local final_filter_sys = ecs.system "final_filter_system"
final_filter_sys.depend "primitive_filter_system"
local ecs = ...
local world = ecs.world

local render = import_package "ant.render"
local cu = render.components
local ru = render.util

local ms = import_package "ant.math" .stack

local primitive_filter_sys = ecs.system "primitive_filter_system"
primitive_filter_sys.singleton "hierarchy_transform_result"

local function update_transform(transform, hierarchy_cache)
	local peid = transform.parent
	local localmat = ms:push_srt_matrix(transform)
	if peid then
		local parentmat = hierarchy_cache[peid]
		localmat = ms(parentmat, localmat, "*P")
	end

	transform.world = localmat
	return localmat
end

--luacheck: ignore self
function primitive_filter_sys:update()
	local transform_cache = self.hierarchy_transform_result
	for _, prim_eid in world:each("primitive_filter") do
		local e = world[prim_eid]		
		local filter = e.primitive_filter
		filter._cache_idx = 1
		local viewtag = filter.view_tag
		local filtertag = filter.filter_tag
		for _, eid in world:each(filtertag) do
			local ce = world[eid]
			local vt = ce[viewtag]
			local ft = ce[filtertag]
			if vt and ft then
				local trans = update_transform(ce.transform, transform_cache)				
				ru.insert_primitive(eid, 
					assert(ce.mesh.assetinfo).handle,
					assert(ce.material.content),
					ms(trans, "m"),
					filter)
			end
		end	
	end
end

-- all filter system need depend 
local final_filter_sys = ecs.system "final_filter_system"
final_filter_sys.depend "primitive_filter_system"
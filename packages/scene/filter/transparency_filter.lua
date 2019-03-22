-- local ecs = ...
-- local world = ecs.world

-- local transparency_filter_sys = ecs.system "transparency_filter_system"

-- transparency_filter_sys.depend "lighting_primitive_filter_system"
-- transparency_filter_sys.dependby "final_filter_system"
-- --luacheck: ignore self
-- function transparency_filter_sys:update()	
-- 	for _, eid in world:each("primitive_filter") do
-- 		local e = world[eid]		
-- 		local filter = e.primitive_filter
-- 		local transparent_result, opaticy_result= {}, {}
-- 		for _, r in ipairs(filter.result) do
-- 			local material = r.material
-- 			local surface_type = material.surface_type
-- 			if surface_type.transparency == "transparent" then
-- 				table.insert(transparent_result, r)
-- 			else
-- 				assert(surface_type.transparency == "opaticy")
-- 				table.insert(opaticy_result, r)
-- 			end
-- 		end

-- 		filter.result, filter.transparent_result = opaticy_result, transparent_result
-- 	end
-- end
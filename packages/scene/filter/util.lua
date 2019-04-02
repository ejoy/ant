local util = {}; util.__index = util

local ms = import_package "ant.math".stack

local function update_uniforms(uniforms, properties)
	for k, v in pairs(properties) do
		assert(type(v) == "table")
		local value = v.value
		local n = #value
		if n > 0 then
			value.n = #value
			uniforms[k] = v
		end
	end
end

local function add_directional_light_properties(world, uniform_properties)
	local dlight_info = {
		directional_lightdir = {name="Light Direction", type="v4", value={}},
		directional_color = {name="Light Color", type="color", value={}},
		directional_intensity = {name="Light Intensity", type="v4",value={}},
		directional_viewproj = {name = "Light View Project Matrix", type="m4", value={}},
	}

	for _, l_eid in world:each("directional_light") do
		local dlight = world[l_eid]
		local l = dlight.directional_light

		-- point from vertex position to light position				
		table.insert(dlight_info.directional_lightdir.value, ms:ref "vector" (ms(dlight.rotation, "diP")))
		table.insert(dlight_info.directional_color.value, l.color)
		table.insert(dlight_info.directional_intensity.value, {l.intensity, 0.28, 0, 0})
		table.insert(dlight_info.directional_viewproj, )
	end

	
	update_uniforms(uniform_properties, dlight_info)
end

--add ambient properties
local function add_ambient_light_propertices(world, uniform_properties)		
	local ambient_data = {
		-- mode = { 0, 0.3, 0, 0},   -- transfer and combine
		-- 							 -- mode :=   0 = "factor" , 1= "color" ,2 = "gradient"
		-- skycolor = {1,1,1,1},
		-- midcolor = {1,1,1,1},
		-- groundcolor = {1,1,1,1},
		ambient_mode = {name ="ambient_mode",type="v4",value ={}},
		ambient_skycolor = {name ="ambient_skycolor",type="color",value={}},
		ambient_midcolor = {name ="ambient_midcolor",type="color",value={}},
		ambient_groundcolor = {name ="ambient_groundcolor",type="color",value={}},
	}

	for _,l_eid in world:each("ambient_light") do 
		local  am_ent = world[l_eid]
		local  l = am_ent.ambient_light 

		local type = 1   -- default = "color"    	
		if l.mode == "factor" then 	
			type = 0
		elseif l.mode == "gradient" then 
			type = 2 
		end 

		table.insert( ambient_data.ambient_mode.value, {type, l.factor, 0, 0} )   
		table.insert( ambient_data.ambient_skycolor.value,  l.skycolor )
		table.insert( ambient_data.ambient_midcolor.value, l.midcolor )
		table.insert( ambient_data.ambient_groundcolor.value, l.groundcolor )
	end 

	
	update_uniforms(uniform_properties, ambient_data)
end 

function util.load_lighting_properties(world, filter)
	local lighting_properties = assert(filter.render_properties.lighting.uniforms)

	add_directional_light_properties(world, lighting_properties)
	add_ambient_light_propertices(world, lighting_properties)

	local camera_entity = world:first_entity("main_queue")	
	if camera_entity then
		lighting_properties["u_eyepos"] = {name = "Eye Position", type="v4", value=camera_entity.camera.eyepos}
	end
end

function util.load_shadow_properties(world, filter)
	local shadow_properties = filter.render_properties.shadow
	local shadow_queue = world:first_entity "shadow"

	if shadow_queue then
		local textures = shadow_properties.textures
		local sm_stage = 4
		for idx, rb in ipairs(shadow_queue.render_target.frame_buffer.render_buffers) do
			local shadowmap = rb.handle			
			local samplername = "s_shadowmap" .. (idx - 1)
			textures[samplername] = {type="texture", stage=sm_stage+idx-1, name="shadowmap0", handle=shadowmap}
		end
	end
end

function util.create_primitve_filter(viewtag, filtertag)
	return {
		view_tag = viewtag,
		filter_tag = filtertag,
		-- result = {
		-- 	case_shadow = {},
		-- 	translcuent = {},
		-- 	opaque = {}
		-- },
		-- render_properties = {
		-- 	lighting = {
		-- 		uniforms = {},
		-- 		textures = {},
		-- 	},
		-- 	shadow = {
		-- 		uniforms = {},
		-- 		textures = {},
		-- 	}
		-- }
	}
end

return util
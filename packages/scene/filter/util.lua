local util = {}; util.__index = util

local ms = import_package "ant.math".stack
local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera

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
	}

	local dlight = world:first_entity "directional_light"
	if dlight then		
		local l = dlight.directional_light

		-- point from vertex position to light position
		local lightdir = ms:ref"vector" 
		ms(lightdir, dlight.rotation, "di=")
		table.insert(dlight_info.directional_lightdir.value, 	lightdir)
		table.insert(dlight_info.directional_color.value, 		l.color)
		table.insert(dlight_info.directional_intensity.value, 	{l.intensity, 0.28, 0, 0})
	end

	
	update_uniforms(uniform_properties, dlight_info)
end

local mode_type = {
	factor = 0,
	color = 1,
	gradient = 2,
}

--add ambient properties
local function add_ambient_light_propertices(world, uniform_properties)		
	local ambient_data = {		
		ambient_mode = {name ="ambient_mode",type="v4",value ={}},
		ambient_skycolor = {name ="ambient_skycolor",type="color",value={}},
		ambient_midcolor = {name ="ambient_midcolor",type="color",value={}},
		ambient_groundcolor = {name ="ambient_groundcolor",type="color",value={}},
	}

	for _,l_eid in world:each("ambient_light") do 
		local  am_ent = world[l_eid]
		local  l = am_ent.ambient_light 

		table.insert( ambient_data.ambient_mode.value, 			{mode_type[l.mode], l.factor, 0, 0})
		table.insert( ambient_data.ambient_skycolor.value,  	l.skycolor)
		table.insert( ambient_data.ambient_midcolor.value, 		l.midcolor)
		table.insert( ambient_data.ambient_groundcolor.value, 	l.groundcolor)
	end 

	update_uniforms(uniform_properties, ambient_data)
end 

function util.load_lighting_properties(world, filter)
	local lighting_properties = assert(filter.render_properties.lighting.uniforms)

	add_directional_light_properties(world, lighting_properties)
	add_ambient_light_propertices(world, lighting_properties)

	local mq = world:first_entity "main_queue"
	if mq then
		local camera = camerautil.get_camera(world, mq.camera_tag)
		lighting_properties["u_eyepos"] = {name = "Eye Position", type="v4", value=camera.eyepos}
	end
end

function util.load_shadow_properties(world, filter)
	local shadow_properties = filter.render_properties.shadow
	local shadow_queue = world:first_entity "shadow"

	if shadow_queue then
		local textures = shadow_properties.textures
		local sm_stage = 4
		for idx, rb in ipairs(shadow_queue.render_target.frame_buffer.render_buffers) do
			local numidx = idx-1
			local samplername = "s_shadowmap" .. numidx
			textures[samplername] = {type="texture", stage=sm_stage+numidx, name=samplername, handle=rb.handle}
		end

		--TODO, view proj matrix calucalate two times, one is here, the other in render_system:update_view_proj function
		-- we can share this calculation
		local camera = shadow_queue.camera
		local _, _, vp = ms:view_proj(camera, camera.frustum, true)
		
		local uniforms = shadow_properties.uniforms
		uniforms["directional_viewproj"] = {
			name = "Directional Light View proj", type = "m4",
			value = {
				n = 1,
				vp,
			}
		}
	end
end

function util.load_postprocess_properties(world, filter)
	local mq = world:first_entity("main_queue")
	if mq then
		local postprocess = filter.render_properties.postprocess
		local fb = mq.render_target.frame_buffer
		if fb then
			local rendertex = fb.render_buffers[1].handle
			postprocess.textures["s_mianview"] = {
				name = "Main view render texture", type = "texture",
				stage = 0, handle = rendertex,
			}
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
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

function util.load_lighting_properties(world, render_properties)
	local lighting_properties = assert(render_properties.lighting.uniforms)

	add_directional_light_properties(world, lighting_properties)
	add_ambient_light_propertices(world, lighting_properties)

	local mq = world:first_entity "main_queue"
	if mq then
		local camera = camerautil.get_camera(world, mq.camera_tag)
		lighting_properties["u_eyepos"] = {name = "Eye Position", type="v4", value=camera.eyepos}
	end
end

local shadow_property_names = {}
for ii=0, 3 do
	shadow_property_names[ii*2] = "s_shadowmap" ..ii
	shadow_property_names[ii*2+1] = "u_shadowmatrix" ..ii
end

function util.load_shadow_properties(world, render_properties)
	local shadow_properties = render_properties.shadow
	
	for _, eid in world:each "shadow" do
		local se = world[eid]
		local shadow = se.shadow
		local csm = shadow.csm
		if csm then
			local idx = csm.index
			local sm_name = shadow_property_names[idx*2]
			local s_mat = shadow_property_names[idx*2+1]

			
		end
	end


end

function util.load_postprocess_properties(world, render_properties)
	local mq = assert(world:first_entity("main_queue"))
	local postprocess = render_properties.postprocess
	local fb = mq.render_target.frame_buffer
	if fb then
		local rendertex = fb.render_buffers[1].handle
		postprocess.textures["s_mianview"] = {
			name = "Main view render texture", type = "texture",
			stage = 0, handle = rendertex,
		}
	end
end

function util.create_primitve_filter(viewtag, filtertag)
	return {
		view_tag = viewtag,
		filter_tag = filtertag,
	}
end

function util.update_render_entity_transform(world, eid, hierarchy_cache)
	local e = world[eid]
	local transform = e.transform
	local peid = transform.parent
	local localmat = ms:srtmat(transform)
	if peid then
		local parentresult = hierarchy_cache[peid]
		local parentmat = parentresult.world
		if parentmat then
			local hie_result = parentresult.hierarchy
			local slotname = transform.slotname
			if hie_result and slotname then
				local hiemat = ms:matrix(hie_result[slotname])
				localmat = ms(parentmat, hiemat, localmat, "**P")
			else
				localmat = ms(parentmat, localmat, "*P")
			end
		end
	end

	local w = transform.world
	ms(w, localmat, "=")
	return w
end
return util
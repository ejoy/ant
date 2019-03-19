--luacheck: ignore self

local ecs = ...
local world = ecs.world

local math = import_package "ant.math"
local ms = math.stack

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

local function append_lighting_properties(filter)

	local function add_directional_light_properties(uniform_properties)
		local dlight_info = {
			directional_lightdir = {name="Light Direction", type="v4", value={}},
			directional_color = {name="Light Color", type="color", value={}},
			directional_intensity = {name="Light Intensity", type="v4",value={}},
		}

		local dirty = false
		for _, l_eid in world:each("directional_light") do
			local dlight = world[l_eid]
			local l = dlight.directional_light

			if l.dirty then
				dirty = true
				-- point from vertex position to light position				
				table.insert(dlight_info.directional_lightdir.value, ms:ref "vector" (ms(dlight.rotation, "diP")))
				table.insert(dlight_info.directional_color.value, l.color)
				table.insert(dlight_info.directional_intensity.value, {l.intensity, 0.28, 0, 0})
				l.dirty = nil
			end
		end

		if dirty then
			update_uniforms(uniform_properties, dlight_info)
		end
	end

	--add ambient properties
	local function add_ambient_light_propertices(uniform_properties)		
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

		local dirty = false

		for _,l_eid in world:each("ambient_light") do 
			local  am_ent = world[l_eid]
			local  l = am_ent.ambient_light 

			if l.dirty then
				dirty = true
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

				l.dirty = nil
			end
		end 

		if dirty then
			update_uniforms(uniform_properties, ambient_data)
		end
	end 

	local lighting_properties = assert(filter.render_properties.lighting.uniforms)

	add_directional_light_properties(lighting_properties)
	add_ambient_light_propertices(lighting_properties)

	local camera_entity = world:first_entity("main_camera")	
	lighting_properties["u_eyepos"] = {name = "Eye Position", type="v4", value=camera_entity.camera.eyepos}
end

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
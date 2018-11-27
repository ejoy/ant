--luacheck: ignore self

local ecs = ...
local world = ecs.world

local ms = require "math.stack"

local function append_lighting_properties(result)

	local function gen_directional_light_properties()
		local properties = {}

		local dlight_info = {
			dir = {},
			color = {},
			intensity = {}
		}

		for _, l_eid in world:each("directional_light") do
			local dlight = world[l_eid]
			local l = dlight.light
		
			-- point from vertex position to light position			
			table.insert(dlight_info.dir, ms(dlight.rotation, "dim")) 
			table.insert(dlight_info.color, l.color)
			table.insert(dlight_info.intensity, {l.intensity, 0.28, 0, 0})
		end

		if next(dlight_info.dir) then
			properties["directional_lightdir"] 	= {name="Light Direction", type="v4", value = dlight_info.dir}
		end
		
		if next(dlight_info.color) then
			properties["directional_color"] 	= {name="Light Color", type="color", value = dlight_info.color}
		end
		if next(dlight_info.intensity) then
			properties["directional_intensity"] = {name="Light Intensity", type="v4", value = dlight_info.intensity}
		end

		return properties
	end

	--add ambient properties
	local function gen_ambient_light_propertices()
		local properties = {} 
		local ambient_data = {		
			-- mode = { 0, 0.3, 0, 0},   -- transfer and combine
			-- 							 -- mode :=   0 = "factor" , 1= "color" ,2 = "gradient"
			-- skycolor = {1,1,1,1},
			-- midcolor = {1,1,1,1},
			-- groundcolor = {1,1,1,1},

			-- 流程看来是需要，数据作为表中第一个子表，因此，按这个方法组织
			mode = {},
			skycolor = {},
			midcolor = {},
			groundcolor = {},
		}


		for _,l_eid in world:each("ambient_light") do 
			local  am_ent = world[l_eid]
			local  data = am_ent.ambient_light 

			local type = 1   -- default = "color"    	
			if data.mode == "factor" then 	
				type = 0
			elseif data.mode == "gradient" then 
				type = 2 
			end 
			table.insert( ambient_data.mode, {type, data.factor, 0, 0} )   
			table.insert( ambient_data.skycolor,  data.skycolor )
			table.insert( ambient_data.midcolor, data.midcolor )
			table.insert( ambient_data.groundcolor, data.groundcolor )

		end 

		if next(ambient_data.mode) then
			properties["ambient_mode"] = { name ="ambient_mode",type="v4",value = ambient_data.mode }
		end

		if next(ambient_data.skycolor) then
			properties["ambient_skycolor"] = { name ="ambient_skycolor",type="color",value=ambient_data.skycolor}
		end

		if next(ambient_data.midcolor) then
			properties["ambient_midcolor"] = { name ="ambient_midcolor",type="color",value=ambient_data.midcolor}
		end
		if next(ambient_data.groundcolor) then
			properties["ambient_groundcolor"] = { name ="ambient_groundcolor",type="color",value=ambient_data.groundcolor}
		end

		-- print("gen ambient light propertices")

		return properties 
	end 


	local lighting_properties = gen_directional_light_properties()
	-- add tested for ambient 
	local ambient_properties  = gen_ambient_light_propertices()

	local camera = world:first_entity("main_camera")
	local eyepos = ms(camera.position, "m")
	lighting_properties["u_eyepos"] = {name = "Eye Position", type="v4", value=eyepos}

	for _, r in ipairs(result) do
		local material = r.material       
		local properties = r.properties   
		local surface_type = material.surface_type
		if surface_type.lighting == "on" then
			-- add lighting 
			for k, v in pairs(lighting_properties) do
				properties[k] = v
			end	
			-- add ambient propertices
			for k,v in pairs(ambient_properties) do 	
				properties[k] = v
			end
		end
	end
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
			append_lighting_properties(filter.result)
		end
	end
end
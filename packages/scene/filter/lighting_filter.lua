--luacheck: ignore self

local ecs = ...
local world = ecs.world

local filterutil = require "filter.util"
local math = import_package "ant.math"
local ms = math.stack

local function append_lighting_properties(result)

	local function add_directional_light_properties(uniform_properties)
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
			uniform_properties["directional_lightdir"] 	= {name="Light Direction", type="v4", value = dlight_info.dir}
		end
		
		if next(dlight_info.color) then
			uniform_properties["directional_color"] 	= {name="Light Color", type="color", value = dlight_info.color}
		end
		if next(dlight_info.intensity) then
			uniform_properties["directional_intensity"] = {name="Light Intensity", type="v4", value = dlight_info.intensity}
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
			uniform_properties["ambient_mode"] = { name ="ambient_mode",type="v4",value = ambient_data.mode }
		end

		if next(ambient_data.skycolor) then
			uniform_properties["ambient_skycolor"] = { name ="ambient_skycolor",type="color",value=ambient_data.skycolor}
		end

		if next(ambient_data.midcolor) then
			uniform_properties["ambient_midcolor"] = { name ="ambient_midcolor",type="color",value=ambient_data.midcolor}
		end
		if next(ambient_data.groundcolor) then
			uniform_properties["ambient_groundcolor"] = { name ="ambient_groundcolor",type="color",value=ambient_data.groundcolor}
		end
	end 

	local lighting_properties = {}
	add_directional_light_properties(lighting_properties)
	add_ambient_light_propertices(lighting_properties)

	local camera = world:first_entity("main_camera")
	local eyepos = ms(camera.position, "m")
	lighting_properties["u_eyepos"] = {name = "Eye Position", type="v4", value=eyepos}

	for _, r in ipairs(result) do
		local material = r.material       
		local properties = r.properties   
		local surface_type = material.surface_type
		if surface_type.lighting == "on" then
			-- add lighting 
			filterutil.append_uniform_properties(properties, lighting_properties)
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
			--[[
				TODO:
				1. create when light properties has been changed, not every frame;
				2. primitive should order by lighting properties, so that not every draw need to take all the lighing properties
				3. 
			]] 
			-- 
			append_lighting_properties(filter.result)
		end
	end
end
local ecs = ...
local world = ecs.world

local function insert_primitive(eid, result)
	local entity = world[eid]

	local mesh = assert(entity.mesh.assetinfo)
	
	local materialcontent = entity.material.content
	assert(#materialcontent >= 1)

	local srt ={s=entity.scale.v, r=entity.rotation.v, t=entity.position.v}
	local mgroups = mesh.handle.group
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

local function push_primitive_in_filter(eid, filter)
    local e = world[eid]
    local can_render = e.can_render

    if can_render == nil or not can_render.visible then
        return 
	end
	
	local meshcomp = e.mesh	
	if meshcomp == nil then
		return 
	end

	insert_primitive(eid, filter.result)
end

--- scene lighting fitler system ------------------------
local lighting_primitive_filter_sys = ecs.system "lighting_primitive_filter_system"
lighting_primitive_filter_sys.singleton "lighting_primitive_filter"
lighting_primitive_filter_sys.singleton "math_stack"

function lighting_primitive_filter_sys:update()
	local filter = self.lighting_primitive_filter
	filter.result = {}

	local ms = self.math_stack

	local function gen_directional_light_properties()
		local properties = {}

		local dlight_info = {
			dir = {},
			color = {},
			intensity = {}
		}

		for _, l_eid in world:each("directional_light") do
			local dlight = world[l_eid]
			local l = dlight.light.v
		
			-- point from vertex position to light position			
			table.insert(dlight_info.dir, ms(dlight.rotation.v, "dim"))
			table.insert(dlight_info.color, l.color)
			table.insert(dlight_info.intensity, l.intensity)
		end

		properties["directional_lightdir"] 	= {name="Light Direction", type="v4", value = dlight_info.dir}
		properties["directional_color"] 	= {name="Light Color", type="color", value = dlight_info.color}
		properties["directional_intensity"] = {name="Light Intensity", type="v4", value = {dlight_info.intensity}}

		return properties
	end

	local lighting_properties = gen_directional_light_properties()

	local camera = world:first_entity("main_camera")
	local eyepos = ms(camera.position.v, "m")
	lighting_properties["eyepos"] = {name = "Eye Position", type="v4", value=eyepos}

	filter.result = {}	
	for _, eid in world:each("can_render") do
		push_primitive_in_filter(eid, filter)
	end

	for _, r in ipairs(filter.result) do
		local material = r.material
		local properties = r.properties
		local surface_type = material.surface_type
		if surface_type.lighting == "on" then
			for k, v in pairs(lighting_properties) do
				-- if properties[k] then
				-- 	print("found lighting property define in material file, property : ", k, 
				-- 			", will overwrite by cureent lighting property")
				-- end

				properties[k] = v
			end			
		end
	end
end

--- scene filter system----------------------------------
-- local primitive_filter_sys = ecs.system "primitive_filter_system"

-- primitive_filter_sys.singleton "primitive_filter"
-- primitive_filter_sys.singleton "math_stack"

-- function primitive_filter_sys:update()
--     local filter = self.primitive_filter
--     filter.result = {}
--     for _, eid in world:each("can_render") do
--         push_primitive_in_filter(eid, filter)
--     end
-- end

----for select filter system-------------------------------
local select_filter_sys = ecs.system "select_filter_system"

select_filter_sys.singleton "math_stack"
select_filter_sys.singleton "select_filter"

function select_filter_sys:update()
    local filter = self.select_filter
    filter.result = {}
    for _, eid in world:each("can_select") do        
        push_primitive_in_filter(eid, filter)
    end
end
local util = {}; util.__index = util

local function create_light_entity(world, tag_comp, name)
	local l_eid = world:new_entity("rotation", "name", "serialize", "light", tag_comp)
	local l_entity = assert(world[l_eid])

	l_entity.name = name

	return l_eid
end

function util.create_directional_light_entity(world, name, color, intensity)
	local l_eid = create_light_entity(world, "directional_light", name or "Directional Light")
	local l_entity = assert(world[l_eid])
	local l = l_entity.light

	l.type = "directional"
	l.angle = nil
	l.range = nil

	l.color = color or {1, 1, 1, 1}
	l.intensity = intensity or 2

	return l_eid
end

function util.create_point_light_entity(world, name)
	local l_eid = create_light_entity(world, "point_light", name or "Point Light")
	world:add_component(l_eid, "position")
	local l_entity = assert(world[l_eid])	

	local l = l_entity.light
	assert(l.type == "point")
	l.angle = nil
	
	return l_eid
end

function util.create_spot_light_entity(world, name)
	local l_eid = create_light_entity(world, "spot_light", name or "Spot Light")
	world:add_component(l_eid, "position")
	
	local l_entity = assert(world[l_eid])
	local l =l_entity.light

	l.type = "spot"	
	
	assert(l.angle)
	assert(l.pos)

	return l_eid
end

-- add tested 
function util.create_ambient_light_entity(world, name, mode, skycolor, midcolor, groundcolor)
	local l_eid = create_light_entity(world,"ambient_light",name or "Ambient Light")
	local l_entity = assert( world[ l_eid] )
	local l = l_entity.light 
	l.type = "ambient"

	local ambient = l_entity.ambient_light
	ambient.mode = mode or "color"              -- default ambient type 
	ambient.factor = 0.3                -- defalut ratio of main lgiht or any special light that in use 
	ambient.skycolor = skycolor or {1,0,0,1}        -- default main ambient color 

	ambient.midcolor = midcolor or {0.9,0.9,1,1}
	ambient.groundcolor  = groundcolor or {0.50,0.74,0.68,1}

	-- debug
	if _DEBUG then
		print("### create ambient light---"..l_entity.ambient_light.mode..' '..l_entity.ambient_light.factor)
		print("### create ambient light---gradient..."..l_entity.ambient_light.midcolor[1],
														l_entity.ambient_light.midcolor[2],
														l_entity.ambient_light.midcolor[3],
														l_entity.ambient_light.midcolor[4] )
	end

	return l_eid 
end 

return util
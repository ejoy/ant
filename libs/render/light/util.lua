local util = {}; util.__index = util

local function create_light_entity(world, tag_comp, name)
	local l_eid = world:new_entity("rotation", "name", "serialize", "light", tag_comp)
	local l_entity = assert(world[l_eid])

	l_entity.name.n = name

	return l_eid
end

function util.create_directional_light_entity(world, name)
	local l_eid = create_light_entity(world, "directional_light", name or "Directional Light")
	local l_entity = assert(world[l_eid])
	local l = l_entity.light.v

	l.type = "directional"
	l.angle = nil
	l.range = nil

	return l_eid
end

function util.create_point_light_entity(world, name)
	local l_eid = create_light_entity(world, "point_light", name or "Point Light")
	world:add_component(l_eid, "position")
	local l_entity = assert(world[l_eid])	

	local l = l_entity.light.v
	assert(l.type == "point")
	l.angle = nil
	
	return l_eid
end

function util.create_spot_light_entity(world, name)
	local l_eid = create_light_entity(world, "spot_light", name or "Spot Light")
	world:add_component(l_eid, "position")
	
	local l_entity = assert(world[l_eid])
	local l =l_entity.light.v

	l.type = "spot"	
	
	assert(l.angle)
	assert(l.pos)

	return l_eid
end

-- add tested 
function util.create_ambient_light_entity(world,name)
	local l_eid = create_light_entity(world,"ambient_light",name or "Ambient Light")
	local l_entity = assert( world[ l_eid] )
	local l = l_entity.light.v 
	l.type = "ambient"

	local ambient = l_entity.ambient_light.data
	ambient.mode = "color"              -- default ambient type 
	ambient.factor = 0.3                -- defalut ratio of main lgiht or any special light that in use 
	ambient.skycolor = {1,0,0,1}        -- default main ambient color 

	-- debug
	print("### create ambient light---"..l_entity.ambient_light.data.mode..' '..l_entity.ambient_light.data.factor)
	print("### create ambient light---gradient..."..l_entity.ambient_light.data.midcolor[1],
													l_entity.ambient_light.data.midcolor[2],
													l_entity.ambient_light.data.midcolor[3],
													l_entity.ambient_light.data.midcolor[4] )

	return l_eid 
end 

return util
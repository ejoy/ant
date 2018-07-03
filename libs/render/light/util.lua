local util = {}; util.__index = util

local function create_light_entity(world, tag_comp, name)
	local l_eid = world:new_entity("position", "rotation", "name", "serialize", "light", tag_comp)
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
	local l_entity = assert(world[l_eid])	

	local l = l_entity.light.v
	assert(l.type == "point")
	l.angle = nil
	
	return l_eid
end

function util.create_spot_light_entity(world, name)
	local l_eid = create_light_entity(world, "spot_light", name or "Spot Light")
	local l_entity = assert(world[l_eid])
	local l =l_entity.light.v

	l.type = "spot"	
	
	assert(l.angle)
	assert(l.pos)

	return l_eid
end

return util
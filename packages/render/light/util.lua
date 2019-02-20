local util = {}; util.__index = util

function util.create_directional_light_entity(world, name, color, intensity)
	return world:create_entity {
		rotation = {0, 0, 0, 0}, 
		name = name, 
		serialize = '', 
		light = true,
		directional_light = {
			color = color or {1, 1, 1, 1},
			intensity = intensity or 2,
		}
	}
end

function util.create_point_light_entity(world, name)
	return world:create_entity {
		position = {0, 0, 0, 1},
		rotation = {0, 0, 0, 0}, 
		name = name, 
		serialize = '', 
		light = true,
		point_light = {
			color = {0.8, 0.8, 0.8, 1},
			intensity = 2,
			range = 1000,
		}
	}
end

function util.create_spot_light_entity(world, name)
	return world:create_entity {
		position = {0, 0, 0, 1},
		rotation = {0, 0, 0, 0}, 
		name = name, 
		serialize = '', 
		light = true,
		spot_light = {
			color = {0.8, 0.8, 0.8, 1},
			intensity = 2,
			range = 1000,
			angle = 60,
		}
	}
end

function util.create_ambient_light_entity(world, name, mode, skycolor, midcolor, groundcolor)	
	return world:create_entity {
		name = name, 
		serialize = '', 
		light = true,
		ambient_light = {
			mode = mode or 'color',
			factor = 0.3,
			skycolor = skycolor or {1,0,0,1},
			midcolor = midcolor or {0.9,0.9,1,1},
			groundcolor = groundcolor or {0.50,0.74,0.68,1},
		}
	}
end 

return util
local util = {}; util.__index = util

local seripkg = import_package 'ant.serialize'

local mathpkg = import_package 'ant.math'
local mu = mathpkg.util

function util.create_directional_light_entity(world, name, color, intensity, rotation)
	return world:create_entity_v2 {
		policy = {
			"directional_light",
			"serialize",
			"name",
		},
		data = {
			transform = mu.srt(nil, rotation, nil),
			name = name,
			serialize = seripkg.create(),
			light = "",
			directional_light = {
				color = color or {1, 1, 1, 1},
				intensity = intensity or 2,
				dirty = true,
			}
		}
	}
end

function util.create_point_light_entity(world, name)
	return world:create_entity_v2 {
		policy = {
			"point_light",
			"serialize",
			"name",
		},
		data = {
			transform = mu.srt(),
			name = name,
			serialize = seripkg.create(),
			light = "",
			point_light = {
				color = {0.8, 0.8, 0.8, 1},
				intensity = 2,
				range = 1000,
				dirty = true,
			}
		}

	}
end

function util.create_spot_light_entity(world, name)
	return world:create_entity_v2 {
		policy = {
			"spot_light",
			"serialize",
			"name",
		},
		data = {
			transform = mu.srt(),
			name = name, 
			serialize = seripkg.create(),
			light = "",
			spot_light = {
				color = {0.8, 0.8, 0.8, 1},
				intensity = 2,
				range = 1000,
				angle = 60,
				dirty = true,
			}
		}

	}
end

function util.create_ambient_light_entity(world, name, mode, skycolor, midcolor, groundcolor)	
	return world:create_entity_v2 {
		policy = {
			"ambient_light",
			"serialize",
			"name",
		},
		data = {
			name = name,
			serialize = seripkg.create(),
			light = "",
			ambient_light = {
				mode = mode or 'color',
				factor = 0.3,
				skycolor = skycolor or {1,0,0,1},
				midcolor = midcolor or {0.9,0.9,1,1},
				groundcolor = groundcolor or {0.50,0.74,0.68,1},
				dirty = true,
			}
		}
	}
end 

return util
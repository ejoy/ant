local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local function vector_init(v)
    local n = #v
    if n == 0 or n > 4 then
        error(string.format("vector only accept 1/4 number:%d", n))
    end
    if #v == 1 then
        local vv = v[1]
        v[2], v[3] = vv, vv
        v[4] = 0
    end
    return math3d.ref(math3d.vector(v))
end

local function vector_save(v)
    assert(type(v) == "userdata")
    local r = math3d.totable(v)
    r.type = nil
    return r
end

local m = ecs.component "position"
m.init = vector_init
m.save = vector_save

local m = ecs.component "direction"
m.init = vector_init
m.save = vector_save

for _, lighttype in ipairs {
	"directional",
	"point",
	"spot",
	"ambient",
} do
	local lightname = lighttype .. "_light"
	local transname = lighttype .. "_transform"
	local t = ecs.transform(transname)
	function t.process_prefab(e)
		e.light = lightname
	end
end

-- light interface

local mathpkg 	= import_package 'ant.math'
local mc		= mathpkg.constant

local ilight 	= ecs.interface "light"

function ilight.create_directional_light_entity(name, color, intensity, direction, position)
	return world:create_entity {
		policy = {
			"ant.render|light.directional",
			"ant.general|name",
		},
		data = {
			position	= world.component "position"(position),
			direction 	= world.component "direction"(direction),
			name		= name,
			light 		= "",
			directional_light = {
				color 	= color or {1, 1, 1, 1},
				intensity= intensity or 2,
			}
		}
	}
end

function ilight.create_point_light_entity(name, dir, pos)
	return world:create_entity {
		policy = {
			"ant.render|point_light",
			"ant.general|name",
		},
		data = {
			direction = world.component "direction"(dir or mc.T_NYAXIS),
			position = world.component "position"(pos or mc.T_ZERO_PT),
			name = name,
			light = "",
			point_light = {
				color = {0.8, 0.8, 0.8, 1},
				intensity = 2,
				range = 1000,
			}
		}

	}
end

function ilight.create_spot_light_entity(name, dir, pos)
	return world:create_entity {
		policy = {
			"ant.render|spot_light",
			"ant.general|name",
		},
		data = {
			direction = world.component "direction"(dir or mc.T_NYAXIS),
			position = world.component "position"(pos or mc.T_ZERO_PT),
			name = name,
			light = "",
			spot_light = {
				color = {0.8, 0.8, 0.8, 1},
				intensity = 2,
				range = 1000,
				angle = 60,
			}
		}

	}
end

function ilight.create_ambient_light_entity(name, mode, skycolor, midcolor, groundcolor)
	return world:create_entity {
		policy = {
			"ant.render|light.ambient",
			"ant.general|name",
		},
		data = {
			name = name,
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
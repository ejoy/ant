local ecs = ...
local world = ecs.world
ecs.component_alias("light", "string")

ecs.component "directional_light"
		.intensity "int"	(50)
		.color "color"

ecs.component "point_light"
		.intensity "int" (50)
		.color "color"
		.range "real"	(100)

ecs.component "spot_light"
		.intensity "int"	(50)
		.color "color"
		.range "real"	(100)
		.angle "real"	(60)

ecs.component "ambient_light"
		.mode "string"	("color")
		.factor "real"	(0.3)
		.skycolor "color"
		.midcolor "color"
		.groundcolor "color"

for _, lighttype in ipairs {
	"directional",
	"point",
	"spot",
	"ambient",
} do
	local policyname = "light." .. lighttype
	local p = ecs.policy(policyname)
	local lightname = lighttype .. "_light"
	p.require_component(lightname)
	p.require_component "light"
	if lighttype == "directional" then
		p.require_component "direction"
		p.unique_component(lightname)
	elseif lighttype == "point" or lighttype == "spot" then
		p.require_component "direction"
		p.require_component "position"
	end

	local transname = lighttype .. "_transform"
	p.require_transform(transname)

	local t = ecs.transform(transname)
	t.input(lightname)
	t.output "light"

	function t.process(e)
		e.light = lightname
	end
end

-- light interface

local seripkg	= import_package 'ant.serialize'
local mathpkg 	= import_package 'ant.math'
local mc		= mathpkg.constant

local ilight 	= ecs.interface "light"

function ilight.create_directional_light_entity(name, color, intensity, direction)
	return world:create_entity {
		policy = {
			"ant.render|light.directional",
			"ant.render|name",
			"ant.serialize|serialize",
		},
		data = {
			direction 	= direction,
			name		= name,
			serialize 	= seripkg.create(),
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
			"ant.render|name",
			"ant.serialize|serialize",
		},
		data = {
			direction = dir or mc.T_NYAXIS,
			position = pos or mc.T_ZERO_PT,
			name = name,
			serialize = seripkg.create(),
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
			"ant.render|name",
			"ant.serialize|serialize",
		},
		data = {
			direction = dir or mc.T_NYAXIS,
			position = pos or mc.T_ZERO_PT,
			name = name, 
			serialize = seripkg.create(),
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
			"ant.render|name",
			"ant.serialize|serialize",
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
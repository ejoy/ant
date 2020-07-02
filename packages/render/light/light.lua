local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local lt = ecs.transform "light_transform"
function lt.process_entity(e)
	e._light = {
		color		= math3d.ref(math3d.vector(e.color or {1, 1, 1, 1})),
		intensity	= math3d.ref(math3d.vector{e.intensity, 0, 0, 0}),
		range		= e.range,
		radian		= e.radian,
	}
end

-- light interface
local ilight 	= ecs.interface "light"

function ilight.create(light)
	return world:create_entity {
		policy = {
			"ant.render|light",
			"ant.general|name",
		},
		data = {
			transform	= math3d.ref(light.transform),
			name		= light.name or "DEFAULT_LIGHT",
			light_type	= assert(light.light_type),
			color		= light.color or {1, 1, 1, 1},
			intensity	= light.intensity or 2,
			range		= light.range,
			radian		= light.radian,
		}
	}
end

function ilight.data(eid)
	return world[eid]._light
end

function ilight.color(eid)
	return world[eid]._light.color
end

function ilight.set_color(eid, color)
	local l = world[eid]._light
	l.color.v = color

	world:pub{"component_changed", "light", eid}
end

function ilight.intensity(eid)
	return world[eid]._light.intensity
end

function ilight.set_intensity(eid, i)
	local ii = world[eid]._light.intensity
	local v = math3d.tovalue(ii)
	v[1] = i
	ii.v = v
	world:pub{"component_changed", "light", eid}
end

function ilight.range(eid)
	return world[eid]._light.range
end

function ilight.set_range(eid, r)
	local e = world[eid]
	if e.light_type == "directional" then
		error("directional light do not have 'range' property")
	end

	e._light.range = r
	world:pub{"component_changed", "light", eid}
end

function ilight.radian(eid)
	return world[eid]._light.radian
end

function ilight.set_radian(eid, r)
	local e = world[eid]
	if e.light_type ~= "spot" then
		error(("%s light do not have 'radian' property"):format(e.light_type))
	end

	e._light.radian = r
	world:pub{"component_changed", "light", eid}
end

local active_dl
function ilight.directional_light()
	return active_dl
end

function ilight.active_directional_light(eid)
	local e = world[eid]
	assert(e.light_type == "directional")
	active_dl = eid
end

local mdl = ecs.action "main_directional_light"
function mdl.init(prefab, idx, value)
	local eid = prefab[idx][1]
	ilight.active_directional_light(eid)
end
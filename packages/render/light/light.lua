local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local ies = world:interface "ant.scene|ientity_state"
local imaterial = world:interface "ant.asset|imaterial"
local iom = world:interface "ant.objcontroller|obj_motion"

local lt = ecs.transform "light_transform"
function lt.process_entity(e)
	local lt = e.light_type
	if (lt == "point" or lt == "spot") and e.range == nil then
		error(("light:%s need define 'range' attribute"):format(lt))
	elseif lt == "spot" and e.radian == nil then
		error("spot light need define 'radian' attribute")
	end
	e._light = {
		color		= math3d.ref(math3d.vector(e.color or {1, 1, 1, 1})),
		intensity	= math3d.ref(math3d.vector{e.intensity or 2, 0, 0, 0}),
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

function ilight.create_light_direction_arrow(eid, data)
	--[[
		cylinde & cone
		1. center in (0, 0, 0, 1)
		2. size is 2
		3. pointer to (0, 1, 0)

		we need to:
		1. rotate arrow, make it rotate to (0, 0, 1)
		2. scale cylinder as it match cylinder_cone_ratio
		3. scale cylinder radius
	]]

	local light_rot = iom.get_rotation(eid)
	local local_rotator = math3d.quaternion{math.rad(90), 0, 0}
	local srt = {s=data.scale, r=math3d.mul(light_rot, local_rotator), t=iom.get_position(eid)}
	local arroweid = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = srt,
			scene_entity = true,
			name = "directional light arrow",
		},
	}

	local cone_rawlen<const> = 2
	local cone_raw_halflen = cone_rawlen * 0.5
	local cylinder_rawlen = cone_rawlen
	local cylinder_len = cone_rawlen * data.cylinder_cone_ratio
	local cylinder_halflen = cylinder_len * 0.5
	local cylinder_scaleY = cylinder_len / cylinder_rawlen

	local cylinder_radius = data.cylinder_rawradius or 0.65

	local cone_raw_centerpos = mc.ZERO_PT
	local cone_centerpos = math3d.add(math3d.add({0, cylinder_halflen, 0, 1}, cone_raw_centerpos), {0, cone_raw_halflen, 0, 1})

	local cylinder_bottom_pos = math3d.vector(0, -cylinder_halflen, 0, 1)
	local cone_top_pos = math3d.add(cone_centerpos, {0, cone_raw_halflen, 0, 1})

	local arrow_center = math3d.mul(0.5, math3d.add(cylinder_bottom_pos, cone_top_pos))

	local cylinder_raw_centerpos = mc.ZERO_PT
	local cylinder_offset = math3d.sub(cylinder_raw_centerpos, arrow_center)

	local cone_offset = math3d.sub(cone_centerpos, arrow_center)

	local cylindereid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible",
			transform =  {
				s = math3d.ref(math3d.mul(100, math3d.vector(cylinder_radius, cylinder_scaleY, cylinder_radius))),
				t = math3d.ref(cylinder_offset),
			},
			material = "/pkg/ant.resources/materials/singlecolor.material",
			mesh = '/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/pCylinder1_P1.meshbin',
			name = "arrow.cylinder",
		},
		action = {
            mount = arroweid,
        }
	}

	imaterial.set_property(cylindereid, "u_color", {1, 0, 0, 1})

	local coneeid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible",
			transform =  {s=100, t=cone_offset},
			material = "/pkg/ant.resources/materials/singlecolor.material",
			mesh = '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "arrow.cone"
		},
		action = {
            mount = arroweid,
		}
	}

	imaterial.set_property(coneeid, "u_color", {1, 0, 0, 1})
end

local mdl = ecs.action "main_directional_light"
function mdl.init(prefab, idx, value)
	local eid = prefab[idx]
	ilight.active_directional_light(eid)
end
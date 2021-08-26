local ecs = ...
local world = ecs.world
local w = world.w

local declmgr	= require "vertexdecl_mgr"
local math3d	= require "math3d"
local bgfx		= require "bgfx"
local iom		= world:interface "ant.objcontroller|obj_motion"
local ies		= world:interface "ant.scene|ientity_state"

local setting	= import_package "ant.settings".setting
local enable_cluster_shading = setting:data().graphic.lighting.cluster_shading ~= 0

local lt = ecs.transform "light_transform"
function lt.process_entity(e)
	local t = e.light_type
	local range = e.range
	local l = {
		color		= e.color or {1, 1, 1, 1},
		intensity	= e.intensity or 2,
	}

	l.range = math.maxinteger
	l.inner_radian, l.outter_radian = 0, 0
	l.inner_cutoff, l.outter_cutoff = 0, 0

	if t == "point" or t == "spot" then
		if range == nil then
			error("point/spot light need range defined!")
		end
		l.range = range
		if t == "spot" then
			local i_r, o_r = e.inner_radian, e.outter_radian
			if i_r == nil or o_r == nil then
				error("spot light need 'inner_radian' and 'outter_radian' defined!")
			end

			if i_r > o_r then
				error(("invalid 'inner_radian' > 'outter_radian':%d, %d"):format(i_r, o_r))
			end
			l.inner_radian, l.outter_radian = i_r, o_r
			l.inner_cutoff = math.cos(l.inner_radian * 0.5)
			l.outter_cutoff = math.cos(l.outter_radian * 0.5)
		end
	end
	e._light = l
end

-- light interface
local ilight 	= ecs.interface "light"

function ilight.create(light)
	return world:deprecated_create_entity {
		policy = {
			"ant.render|light",
			"ant.general|name",
		},
		data = {
			transform	= light.transform,
			name		= light.name or "DEFAULT_LIGHT",
			light_type	= assert(light.light_type),
			color		= light.color or {1, 1, 1, 1},
			intensity	= light.intensity or 2,
			range		= light.range,
			radian		= light.radian,
			make_shadow	= light.make_shadow,
			state		= ies.create_state "visible",
			motion_type = light.motion_type or "dynamic",
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
	local c = l.color
	for i=1, 4 do c[i] = color[i] end

	world:pub{"component_changed", "light", eid, "color"}
end

function ilight.intensity(eid)
	return world[eid]._light.intensity
end

function ilight.set_intensity(eid, i)
	world[eid]._light.intensity = i
	world:pub{"component_changed", "light", eid, "intensity"}
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
	world:pub{"component_changed", "light", eid, "range"}
end

function ilight.inner_radian(eid)
	return world[eid]._light.inner_radian
end

local function check_spot_light(eid)
	local e = world[eid]
	if e.light_type ~= "spot" then
		error(("%s light do not have 'radian' property"):format(e.light_type))
	end
	return e
end

local spot_radian_threshold<const> = 10e-6
function ilight.set_inner_radian(eid, r)
	local e = check_spot_light(eid)

	local l = e._light
	l.inner_radian = math.min(l.outter_radian-spot_radian_threshold, r)
	l.inner_cutoff = math.cos(l.inner_radian*0.5)
	world:pub{"component_changed", "light", eid, "inner_radian"}
end

function ilight.outter_radian(eid)
	return world[eid]._light.outter_radian
end

function ilight.set_outter_radian(eid, r)
	local e = check_spot_light(eid)

	local l = e._light
	l.outter_radian = math.max(r, l.inner_radian+spot_radian_threshold)
	l.outter_cutoff = math.cos(l.outter_radian*0.5)
	world:pub{"component_changed", "light", eid, "outter_radian"}
end

function ilight.inner_cutoff(eid)
	return world[eid]._light.inner_cutoff
end

function ilight.outter_cutoff(eid)
	return world[eid]._light.outter_cutoff
end

local lighttypes = {
	directional = 0,
	point = 1,
	spot = 2,
}

local function count_visible_light()
	local l = {}
	for _, leid in world:each "light_type" do
		if ies.can_visible(leid) then
			l[#l+1] = leid
		end
	end
	return l
end

ilight.count_visible_light = count_visible_light

local function create_light_buffers()
	local lights = {}
	for _, leid in ipairs(count_visible_light()) do
		local le = world[leid]
		local p	= math3d.tovalue(iom.get_position(leid))
		local d	= math3d.tovalue(math3d.inverse(iom.get_direction(leid)))
		local c = ilight.color(leid)
		local t	= le.light_type
		local enable<const> = 1
		lights[#lights+1] = ('f'):rep(16):pack(
			p[1], p[2], p[3], ilight.range(leid) or math.maxinteger,
			d[1], d[2], d[3], enable,
			c[1], c[2], c[3], c[4],
			lighttypes[t], ilight.intensity(leid),
			ilight.inner_cutoff(leid) or 0,	ilight.outter_cutoff(leid) or 0)
	end
    return lights
end

function ilight.use_cluster_shading()
	return enable_cluster_shading
end

local light_buffer = bgfx.create_dynamic_vertex_buffer(1, declmgr.get "t40".handle, "ra")

local function update_light_buffers()
	local lights = create_light_buffers()
	if #lights > 0 then
		bgfx.update(light_buffer, 0, bgfx.memory_buffer(table.concat(lights, "")))
	end
end

function ilight.light_buffer()
	return light_buffer
end

local lightsys = ecs.system "light_system"
local light_comp_mb = world:sub{"component_changed", "light"}
local light_state_mb = world:sub{"component_changed", "state"}
local light_register_mb = world:sub{"component_register", "light_type"}

function lightsys:update_lights()
	local changed = false
	for v in w:select "scene_changed eid:in" do
		local le = world[v.eid]
		if le and le.light_type then
			changed = true
			break
		end
	end

	if not changed then
		for _ in light_comp_mb:each() do
			changed = true
			break
		end
	end

	if not changed then
		for msg in light_state_mb:each() do
			local eid = msg[3]
			local le = world[eid]
			if le and le.light_type then
				changed = true
			end
			break
		end
	end

	if not changed then
		for _ in light_register_mb:each() do
			changed = true
			break
		end
	end

	if not changed then
		for _, eid in world:each "removed" do
			local e = world[eid]
			if e.light_type then
				changed = true
				break
			end
		end
	end

	if changed then
		update_light_buffers()
	end
end
local ecs = ...
local world = ecs.world
local w = world.w

local renderpkg	= import_package "ant.render"
local layoutmgr	= renderpkg.layoutmgr

local math3d	= require "math3d"
local bgfx		= require "bgfx"
local iom		= ecs.require "ant.objcontroller|obj_motion"
local iexposure = ecs.require "ant.camera|exposure"
local imaterial = ecs.require "ant.render|material"

local setting	= import_package "ant.settings"
local ENABLE_CLUSTER_SHADERING<const> = setting:get "graphic/lighting/cluster_shading/enable"
local CLUSTER_MAX_LIGHT_COUNT<const> = setting:get "graphic/lighting/cluster_shading/max_light" or 0

local DEFAULT_LIGHT<const> = {
	directional = {
		intensity = 130000,
		unit = "lux",
	},
	point = {
		intensity = 12000,
		unit = "candela",
	},
	spot = {
		intensity = 12000,
		unit = "candela",
	},
	area = {
		intensity = 12000,
		unit = "candela"
	}
}

local changed = false

local function setChanged()
	changed = true
end

local function isChanged()
	if changed then
		changed = false
		return true
	end
	return w:check "scene_changed light"
end

local ilight = {}

local function check_intensity_unit(unit)
	assert(unit == "lux" or unit == "candela")
	return unit
end

function ilight.default_intensity(t)
	return DEFAULT_LIGHT[t].intensity
end

function ilight.default_intensity_unit(t)
	return DEFAULT_LIGHT[t].unit
end

function ilight.create(light)
	local template = {
		policy = {
			"ant.render|light",
		},
		data = {
			scene = {
				s = light.srt.s,
				r = light.srt.r,
				t = light.srt.t,
			},
			make_shadow	= light.make_shadow,
			light = {
				type		= assert(light.type),
				motion_type = assert(light.motion_type),
				color		= assert(light.color),
				intensity	= assert(light.intensity),
				intensity_unit=check_intensity_unit(light.intensity_unit),
				range		= light.range,
				inner_radian= light.inner_radian,
				outter_radian= light.outter_radian,
				angular_radius=light.angular_radius,
			},
			visible = true,
		},
		tag = {light.name}
	}
	return world:create_entity(template), template
end

function ilight.data(e)
	return e.light
end

function ilight.color(e)
	return e.light.color
end

function ilight.set_color(e, color)
	ilight.set_color_rgb(e, color[1], color[2], color[3])
end

function ilight.set_color_rgb(e, r, g, b)
	local c = e.light.color
	c[1], c[2], c[3] = r, g, b
	setChanged()
end

function ilight.intensity(e)
	return e.light.intensity
end

--[[
	the reference of light intensity and unit:
	https://google.github.io/filament/Filament.html#lighting/units
]]
function ilight.set_intensity(e, i, unit)
	local l = e.light
	if unit then
		l.intensity_unit = check_intensity_unit(unit)
	else
		unit = assert(l.intensity_unit)
	end

	local t = l.type
	if t == "directional" then
		l.intensity = i
		assert(unit == "lux", "directional light's intensity unit must only be 'lux'")
	elseif t == "point" then
		l.intensity = unit == "candela" and i / (math.pi*0.25) or i
	elseif t == "spot" then
		local r = assert(l.outter_radian)
		l.intensity = unit == "candela" and i / (2.0*math.pi*(1.0-math.cos(r*0.5))) or i
	end
	setChanged()
end

function ilight.intensity_unit(e)
	return e.light.intensity_unit
end

function ilight.range(e)
	return e.light.range
end

function ilight.set_range(e, r)
	if e.light.type == "directional" then
		error "directional light do not have 'range' property"
	end
	e.light.range = r
	setChanged()
end

function ilight.inner_radian(e)
	return e.light.inner_radian
end

local function check_spot_light(e)
	if e.light.type ~= "spot" then
		error(("%s light do not have 'radian' property"):format(e.light.type))
	end
end

local spot_radian_threshold<const> = 10e-6
function ilight.set_inner_radian(e, r)
	check_spot_light(e)
	local l = e.light
	l.inner_radian = math.min(l.outter_radian-spot_radian_threshold, r)
	l.inner_cutoff = math.cos(l.inner_radian*0.5)
	setChanged()
end

function ilight.outter_radian(e)
	return e.light.outter_radian
end

function ilight.set_outter_radian(e, r)
	check_spot_light(e)
	local l = e.light
	l.outter_radian = math.max(r, l.inner_radian+spot_radian_threshold)
	l.outter_cutoff = math.cos(l.outter_radian*0.5)
	setChanged()
end

function ilight.inner_cutoff(e)
	return e.light.inner_cutoff
end

function ilight.outter_cutoff(e)
	return e.light.outter_cutoff
end

function ilight.which_type(e)
	return e.light.type
end

function ilight.make_shadow(e)
	return e.make_shadow
end

function ilight.set_make_shadow(e, enable)
	e.make_shadow = enable
end

function ilight.motion_type(e)
	return e.light.motion_type
end

function ilight.set_motion_type(e, t)
	e.light.motion_type = t
end

function ilight.angular_radius(e)
	return e.light.angular_radius
end

function ilight.set_angular_radius(e, ar)
	e.light.angular_radius = ar
end

local lighttypes = {
	directional = 0,
	point = 1,
	spot = 2,
}

local function count_visible_light()
	local n = 0
	for _ in w:select "light visible" do
		n = n + 1
	end
	return n
end

ilight.count_visible_light = count_visible_light

local function create_light_buffers()
	local lights = {}
	local mq = w:first("main_queue camera_ref:in")
    local camera <close> = world:entity(mq.camera_ref)
	local ev = iexposure.exposure(camera)

	local function pack_light(e)
		local dir, pos = math3d.index(e.scene.worldmat, 3, 4)
		dir = math3d.inverse(dir)
		local dx, dy, dz = math3d.index(dir, 1, 2, 3)
		local px, py, pz = math3d.index(pos, 1, 2, 3)
		local c = e.light.color
		local t	= e.light.type
		local enable<const> = 1
		return ('f'):rep(16):pack(
			px, py, pz, e.light.range or math.maxinteger,
			dx, dy, dz, enable,
			c[1], c[2], c[3], 0.0,	-- not use
			lighttypes[t],
			e.light.intensity * ev,
			e.light.inner_cutoff or 0,
			e.light.outter_cutoff or 0
		)
	end

	for e in w:select "directional_light light:in visible scene:in" do
		lights[#lights+1] = pack_light(e)
	end

	local culledlightcount = 0
	for e in w:select "light:in directional_light:absent visible scene:in" do
		lights[#lights+1] = pack_light(e)
		culledlightcount = culledlightcount + 1
	end
    return lights, culledlightcount
end

local light_buffer = bgfx.create_dynamic_vertex_buffer(1, layoutmgr.get "t40".handle, "ra")

local function update_light_buffers()
	local lights, culledlightcount = create_light_buffers()
	if #lights ~= 0 then
		bgfx.update(light_buffer, 0, bgfx.memory_buffer(table.concat(lights, "")))
	end
	imaterial.system_attrib_update("u_light_count", math3d.vector(#lights, culledlightcount, CLUSTER_MAX_LIGHT_COUNT, 0))
end

function ilight.light_buffer()
	return light_buffer
end

local lightsys = ecs.system "light_system"

function lightsys:component_init()
	for e in w:select "INIT light:in" do
		local t = e.light.type
		local tag = t .."_light"
		e[tag] = true
		w:extend(e, tag .. "?out")
	end
end

function lightsys:entity_init()
	for e in w:select "INIT light:in" do
		setChanged()
		local l 		= e.light
		local t 		= assert(l.type)
		assert(l.color or l.intensity or l.intensity_unit or l.motion_type, "light's 'color' or 'intensity' or 'intensity_unit' must not be nil")
		l.angular_radius= l.angular_radius or math.rad(0.27)
		if t == "point" then
			if l.range == nil then
				error("point light need range defined!")
			end
			l.inner_radian = 0
			l.outter_radian = 0
			l.inner_cutoff = 0
			l.outter_cutoff = 0
		elseif t == "spot" then
			if l.range == nil then
				error("spot light need range defined!")
			end
			local i_r, o_r = l.inner_radian, l.outter_radian
			if i_r == nil or o_r == nil then
				error("spot light need 'inner_radian' and 'outter_radian' defined!")
			end
			if i_r > o_r then
				error(("invalid 'inner_radian' > 'outter_radian':%d, %d"):format(i_r, o_r))
			end
			l.inner_cutoff = math.cos(l.inner_radian * 0.5)
			l.outter_cutoff = math.cos(l.outter_radian * 0.5)
		else
			l.range = math.maxinteger
			l.inner_radian = 0
			l.outter_radian = 0
			l.inner_cutoff = 0
			l.outter_cutoff = 0
		end
	end
end

function lightsys:init_world()
	if not ENABLE_CLUSTER_SHADERING then
		imaterial.system_attrib_update("b_light_info", ilight.light_buffer())
	end
end

function lightsys:entity_remove()
	for _ in w:select "REMOVED light" do
		setChanged()
		return
	end
end

function lightsys:update_system_properties()
	if isChanged() then
		update_light_buffers()
	end
end

return ilight

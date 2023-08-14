local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = ecs.require "ant.asset|material"

--[[
	this code from bgfx example-36, references:
	[1] R. Perez, R. Seals, and J. Michalsky."An All-Weather Model for Sky Luminance Distribution".
 	Solar Energy, Volume 50, Number 3 (March 1993), pp. 235–245.
    
    [2] A. J. Preetham, Peter Shirley, and Brian Smits. "A Practical Analytic Model for Daylight",
        Proceedings of the 26th Annual Conference on Computer Graphics and Interactive Techniques,
        1999, pp. 91–100.
        https://www.cs.utah.edu/~shirley/papers/sunsky/sunsky.pdf
    
    [3] E. Lengyel, Game Engine Gems, Volume One. Jones & Bartlett Learning, 2010. pp. 219 - 234
]]

local mu = import_package "ant.math".util
local math3d = require "math3d"

local MONTHS<const> = {
	January		= 0,
	February	= 1,
	March		= 2,
	April		= 3,
	May			= 4,
	June		= 5,
	July		= 6,
	August		= 7,
	September	= 8,
	October		= 9,
	November	= 10,
	December	= 11,
}

-- HDTV rec. 709 matrix.
local M_XYZ2RGB = math3d.constant("mat", {
	3.240479, -0.969256,  0.055648, 0, 
	-1.53715,   1.875991, -0.204043, 0,
	-0.49853,   0.041556,  1.057311, 0,
	0, 			0, 			0, 		  1})

local function xyz2rgb(xyz)
	-- // Converts color repesentation from CIE XYZ to RGB color-space.
	return math3d.transform(M_XYZ2RGB, xyz, 0)
end

-- Precomputed luminance of sunlight in XYZ colorspace.
-- Computed using code from Game Engine Gems, Volume One, chapter 15. Implementation based on Dr. Richard Bird model.
-- This table is used for piecewise linear interpolation. Transitions from and to 0.0 at sunset and sunrise are highly inaccurate
local sun_luminance_XYZ = {
	[5.0]  = math3d.constant("v4", { 0.000000,  0.000000,  0.000000, 0}),
	[7.0]  = math3d.constant("v4", {12.703322, 12.989393,  9.100411, 0}),
	[8.0]  = math3d.constant("v4", {13.202644, 13.597814, 11.524929, 0}),
	[9.0]  = math3d.constant("v4", {13.192974, 13.597458, 12.264488, 0}),
	[10.0] = math3d.constant("v4", {13.132943, 13.535914, 12.560032, 0}),
	[11.0] = math3d.constant("v4", {13.088722, 13.489535, 12.692996, 0}),
	[12.0] = math3d.constant("v4", {13.067827, 13.467483, 12.745179, 0}),
	[13.0] = math3d.constant("v4", {13.069653, 13.469413, 12.740822, 0}),
	[14.0] = math3d.constant("v4", {13.094319, 13.495428, 12.678066, 0}),
	[15.0] = math3d.constant("v4", {13.142133, 13.545483, 12.526785, 0}),
	[16.0] = math3d.constant("v4", {13.201734, 13.606017, 12.188001, 0}),
	[17.0] = math3d.constant("v4", {13.182774, 13.572725, 11.311157, 0}),
	[18.0] = math3d.constant("v4", {12.448635, 12.672520,  8.267771, 0}),
	[20.0] = math3d.constant("v4", { 0.000000,  0.000000,  0.000000, 0}),
};


-- Precomputed luminance of sky in the zenith point in XYZ colorspace.
-- Computed using code from Game Engine Gems, Volume One, chapter 15. Implementation based on Dr. Richard Bird model.
-- This table is used for piecewise linear interpolation. Day/night transitions are highly inaccurate.
-- The scale of luminance change in Day/night transitions is not preserved.
-- Luminance at night was increased to eliminate need the of HDR render.
local sky_luminance_XYZ = {
	[0.0]  = math3d.constant("v4", {0.308,    0.308,    0.411   , 0}),
	[1.0]  = math3d.constant("v4", {0.308,    0.308,    0.410   , 0}),
	[2.0]  = math3d.constant("v4", {0.301,    0.301,    0.402   , 0}),
	[3.0]  = math3d.constant("v4", {0.287,    0.287,    0.382   , 0}),
	[4.0]  = math3d.constant("v4", {0.258,    0.258,    0.344   , 0}),
	[5.0]  = math3d.constant("v4", {0.258,    0.258,    0.344   , 0}),
	[7.0]  = math3d.constant("v4", {0.962851, 1.000000, 1.747835, 0}),
	[8.0]  = math3d.constant("v4", {0.967787, 1.000000, 1.776762, 0}),
	[9.0]  = math3d.constant("v4", {0.970173, 1.000000, 1.788413, 0}),
	[10.0] = math3d.constant("v4", {0.971431, 1.000000, 1.794102, 0}),
	[11.0] = math3d.constant("v4", {0.972099, 1.000000, 1.797096, 0}),
	[12.0] = math3d.constant("v4", {0.972385, 1.000000, 1.798389, 0}),
	[13.0] = math3d.constant("v4", {0.972361, 1.000000, 1.798278, 0}),
	[14.0] = math3d.constant("v4", {0.972020, 1.000000, 1.796740, 0}),
	[15.0] = math3d.constant("v4", {0.971275, 1.000000, 1.793407, 0}),
	[16.0] = math3d.constant("v4", {0.969885, 1.000000, 1.787078, 0}),
	[17.0] = math3d.constant("v4", {0.967216, 1.000000, 1.773758, 0}),
	[18.0] = math3d.constant("v4", {0.961668, 1.000000, 1.739891, 0}),
	[20.0] = math3d.constant("v4", {0.264,    0.264,    0.352   , 0}),
	[21.0] = math3d.constant("v4", {0.264,    0.264,    0.352   , 0}),
	[22.0] = math3d.constant("v4", {0.290,    0.290,    0.386   , 0}),
	[23.0] = math3d.constant("v4", {0.303,    0.303,    0.404   , 0}),
};


-- Turbidity tables. Taken from:
-- A. J. Preetham, P. Shirley, and B. Smits. A Practical Analytic Model for Daylight. SIGGRAPH ’99
-- Coefficients correspond to xyY colorspace.
local ABCDE = {
	math3d.constant("v4", {-0.2592, -0.2608, -1.4630, 0}),
	math3d.constant("v4", { 0.0008,  0.0092,  0.4275, 0}),
	math3d.constant("v4", { 0.2125,  0.2102,  5.3251, 0}),
	math3d.constant("v4", {-0.8989, -1.6537, -2.5771, 0}),
	math3d.constant("v4", { 0.0452,  0.0529,  0.3703, 0}),
}

local ABCDE_t = {
	math3d.constant("v4", {-0.0193, -0.0167,  0.1787, 0}),
	math3d.constant("v4", {-0.0665, -0.0950, -0.3554, 0}),
	math3d.constant("v4", {-0.0004, -0.0079, -0.0227, 0}),
	math3d.constant("v4", {-0.0641, -0.0441,  0.1206, 0}),
	math3d.constant("v4", {-0.0033, -0.0109, -0.0670, 0}),
}

local function compute_PerezCoeff(turbidity)
	assert(#ABCDE == #ABCDE_t)
	local r = {}
	local n = #ABCDE
	for i=1, n do
		local v0, v1 = ABCDE_t[i], ABCDE[i]
		r[i] = math3d.muladd(v0, turbidity, v1)
	end
	return math3d.array_vector(r)
end

local days_in_month<const> = {
	31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
}

local sum_days_in_month = {days_in_month[1]}; do
	for i=2, 12 do
		local d = days_in_month[i]
		sum_days_in_month[i] = sum_days_in_month[i-1]+d
	end
end

local day_offset<const> = 15

local function select_which_day(whichmonth)
	local month<const> = MONTHS[whichmonth]
	return sum_days_in_month[month] + day_offset
end

-- Controls sun position according to time, month, and observer's latitude.
-- this data get from: https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html

local function calc_sun_orbit_delta(day, ecliptic_obliquity)
	local lambda = math.rad(280.46 + 0.9856474 * day);
	return math.asin(math.sin(ecliptic_obliquity) * math.sin(lambda))
end

local function calc_sun_direction(skycomp)
	-- should move to C
	local latitude = skycomp.latitude
	local whichhour = skycomp.which_hour - 12	-- this algorithm take hour from [-12, 12]
	local delta = calc_sun_orbit_delta(select_which_day(skycomp.month), skycomp.ecliptic_obliquity)

	local hh = whichhour * math.pi / 12 --whichhour * math.pi * 2 / 24
	local azimuth = math.atan(
			math.sin(hh), 
			math.cos(hh) * math.cos(latitude) - math.tan(delta) * math.cos(latitude))

	local altitude = math.asin(math.sin(latitude) * math.sin(delta) + 
								math.cos(latitude) * math.cos(delta) * math.cos(hh))

	local rot0 = math3d.quaternion{axis=skycomp.updir, r=-azimuth}
	local dir  = math3d.transform(rot0, skycomp.northdir, 0)
	local uxd  = math3d.cross(skycomp.updir, dir)
	
	local rot1 = math3d.quaternion{axis=uxd, r=-altitude}
	return math3d.normalize(math3d.transform(rot1, dir, 0))
end

local ps_sys = ecs.system "procedural_sky_system"

local function fetch_value_operation(t)
	local tt = {}
	for k in pairs(t) do
		tt[#tt+1] = k
	end

	table.sort(tt)
	
	local function binary_search(value)
		local from, to = 1, #tt
		assert(to > 0)
		while from <= to do
			local mid = math.floor((from + to) / 2)
			local value2 = tt[mid]
			if value == value2 then
				return mid, mid
			elseif value < value2 then
				to = mid - 1
			else
				from = mid + 1
			end
		end
	
		if from > to then
			local v = to
			to = from
			from = v
		end
		return math.max(from, 1), math.min(to, #tt)
	end
	
	local cache = {}
	return function(time)
		local result = cache[time]
		if result == nil then
			local l,h = binary_search(time)
			if l == h then
				result = t[tt[l]]
			else
				local li, hi = tt[l], tt[h]
				result = math3d.lerp(t[li], t[hi], mu.ratio(li, hi, time))
			end

			cache[time] = math3d.ref(result)
		end
		
		return result
	end
end

local sun_luminance_fetch = fetch_value_operation(sun_luminance_XYZ)
local sky_luminance_fetch = fetch_value_operation(sky_luminance_XYZ)

local function update_sky_parameters(e)
	local skycomp = e.procedural_sky
	local hour = skycomp.which_hour
	imaterial.set_property(e, "u_sunDirection", skycomp.sundir)
	
	--imaterial.set_property(e, "u_sunLuminance", xyz2rgb(sun_luminance_fetch(hour)))
	imaterial.set_property(e, "u_skyLuminanceXYZ", sky_luminance_fetch(hour))
	imaterial.set_property(e, "u_parameters", math3d.vector(skycomp.sun_size, skycomp.sun_bloom, skycomp.intensity, hour))

	imaterial.set_property(e, "u_perezCoeff", compute_PerezCoeff(skycomp.turbidity))
end

local function sync_directional_light(e)
	local skycomp = e.procedural_sky
	local sunlight_eid = skycomp.attached_sun_light
	if sunlight_eid then
		local dlight = world[sunlight_eid]
		dlight.direction.v = math3d.torotation(skycomp.sundir)
	end
end

local function update_hour(skycomp, deltatime, unit)
	unit = unit or 24
	skycomp.which_hour = (skycomp.which_hour + deltatime) % unit
end

local timer = ecs.require "ant.timer|timer_system"

local function update_sun()
	local delta = timer.delta()
	for e in w:select "procedural_sky:in" do
		local skycomp = e.procedural_sky
		update_hour(skycomp, delta)
		skycomp.sundir.v = calc_sun_direction(skycomp)
	end
end

local function init_procedural_sky(e)
	local skycomp = e.procedural_sky
	skycomp.ecliptic_obliquity = math.rad(23.44)	--the earth's ecliptic obliquity is 23.44
	skycomp.northdir = math3d.ref(math3d.vector(1, 0, 0, 0))
	skycomp.updir  	= math3d.ref(math3d.vector(0, 1, 0, 0))
	skycomp.sundir 	= math3d.ref(calc_sun_direction(skycomp))
	skycomp.intensity = 1
	skycomp.sun_size = 0.02
	skycomp.sun_bloom = 3.0
end

function ps_sys:entity_init()
	for e in w:select "INIT procedural_sky:in procedural_sky_changed?out" do
		init_procedural_sky(e)
		e.procedural_sky_changed = true
	end
end

function ps_sys:data_changed()
	for e in w:select "procedural_sky_changed procedural_sky:in render_object filter_material:in" do
		update_sky_parameters(e)
		sync_directional_light(e)
	end
	w:clear "procedural_sky_changed"
	--update_sun()
end

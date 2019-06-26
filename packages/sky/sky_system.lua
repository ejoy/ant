local ecs = ...
local world = ecs.world

local fs = require "filesystem"

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mu = mathpkg.util

local MONTHS = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}

-- HDTV rec. 709 matrix.
local M_XYZ2RGB = ms:ref "matrix" {
	--  3.240479, -0.969256,  0.055648,
	-- -1.53715,   1.875991, -0.204043,
	-- -0.49853,   0.041556,  1.057311,
	-- we need transpose
	3.240479, 	-1.53715, 	-0.49853, 0, 
	-0.969256, 	1.875991, 	0.041556, 0,
	0.055648,  	-0.204043,  1.057311, 0,
	0, 			0, 			0, 		  1,
}

local function xyz2rgb(xyz)
	-- // Converts color repesentation from CIE XYZ to RGB color-space.
	return ms(M_XYZ2RGB, xyz, "*P")
end

-- Precomputed luminance of sunlight in XYZ colorspace.
-- Computed using code from Game Engine Gems, Volume One, chapter 15. Implementation based on Dr. Richard Bird model.
-- This table is used for piecewise linear interpolation. Transitions from and to 0.0 at sunset and sunrise are highly inaccurate
local sun_luminance_XYZ = {
	[5.0]  =  {  0.000000,  0.000000,  0.000000 },
	[7.0]  =  { 12.703322, 12.989393,  9.100411 },
	[8.0]  =  { 13.202644, 13.597814, 11.524929 },
	[9.0]  =  { 13.192974, 13.597458, 12.264488 },
	[10.0] =  { 13.132943, 13.535914, 12.560032 },
	[11.0] =  { 13.088722, 13.489535, 12.692996 },
	[12.0] =  { 13.067827, 13.467483, 12.745179 },
	[13.0] =  { 13.069653, 13.469413, 12.740822 },
	[14.0] =  { 13.094319, 13.495428, 12.678066 },
	[15.0] =  { 13.142133, 13.545483, 12.526785 },
	[16.0] =  { 13.201734, 13.606017, 12.188001 },
	[17.0] =  { 13.182774, 13.572725, 11.311157 },
	[18.0] =  { 12.448635, 12.672520,  8.267771 },
	[20.0] =  {  0.000000,  0.000000,  0.000000 },
};


-- Precomputed luminance of sky in the zenith point in XYZ colorspace.
-- Computed using code from Game Engine Gems, Volume One, chapter 15. Implementation based on Dr. Richard Bird model.
-- This table is used for piecewise linear interpolation. Day/night transitions are highly inaccurate.
-- The scale of luminance change in Day/night transitions is not preserved.
-- Luminance at night was increased to eliminate need the of HDR render.
local sky_luminance_XYZ = {
	[0.0]  =  { 0.308,    0.308,    0.411    },
	[1.0]  =  { 0.308,    0.308,    0.410    },
	[2.0]  =  { 0.301,    0.301,    0.402    },
	[3.0]  =  { 0.287,    0.287,    0.382    },
	[4.0]  =  { 0.258,    0.258,    0.344    },
	[5.0]  =  { 0.258,    0.258,    0.344    },
	[7.0]  =  { 0.962851, 1.000000, 1.747835 },
	[8.0]  =  { 0.967787, 1.000000, 1.776762 },
	[9.0]  =  { 0.970173, 1.000000, 1.788413 },
	[10.0] =  { 0.971431, 1.000000, 1.794102 },
	[11.0] =  { 0.972099, 1.000000, 1.797096 },
	[12.0] =  { 0.972385, 1.000000, 1.798389 },
	[13.0] =  { 0.972361, 1.000000, 1.798278 },
	[14.0] =  { 0.972020, 1.000000, 1.796740 },
	[15.0] =  { 0.971275, 1.000000, 1.793407 },
	[16.0] =  { 0.969885, 1.000000, 1.787078 },
	[17.0] =  { 0.967216, 1.000000, 1.773758 },
	[18.0] =  { 0.961668, 1.000000, 1.739891 },
	[20.0] =  { 0.264,    0.264,    0.352    },
	[21.0] =  { 0.264,    0.264,    0.352    },
	[22.0] =  { 0.290,    0.290,    0.386    },
	[23.0] =  { 0.303,    0.303,    0.404    },
};


-- Turbidity tables. Taken from:
-- A. J. Preetham, P. Shirley, and B. Smits. A Practical Analytic Model for Daylight. SIGGRAPH ’99
-- Coefficients correspond to xyY colorspace.
local ABCDE = {
	ms:ref "vector" { -0.2592, -0.2608, -1.4630 },
	ms:ref "vector" {  0.0008,  0.0092,  0.4275 },
	ms:ref "vector" {  0.2125,  0.2102,  5.3251 },
	ms:ref "vector" { -0.8989, -1.6537, -2.5771 },
	ms:ref "vector" {  0.0452,  0.0529,  0.3703 },
}

local ABCDE_t = {
	ms:ref "vector" { -0.0193, -0.0167,  0.1787 },
	ms:ref "vector" { -0.0665, -0.0950, -0.3554 },
	ms:ref "vector" { -0.0004, -0.0079, -0.0227 },
	ms:ref "vector" { -0.0641, -0.0441,  0.1206 },
	ms:ref "vector" { -0.0033, -0.0109, -0.0670 },
}

-- Controls sun position according to time, month, and observer's latitude.
-- this data get from: https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html
local ps = ecs.component "procedural_sky"
	.w 			"int" (1)
	.h 			"int" (1)
	.which_hour "real" (12)
	.turbidity 	"real" (0.5)
	.month 		"string" ("June")
	.latitude 	"real" (math.rad(50))

local function compute_PerezCoeff(turbidity)
	assert(#ABCDE == #ABCDE_t)
	local result = {}
	for i=1, #ABCDE do
		local v0, v1 = ABCDE_t[i], ABCDE[i]
		result[#result+1] = ms(v1, {turbidity}, v0, "*+P")
	end
	
	return result
end

local function fetch_month_index_op()
	local remapper = {}
	for idx, m in ipairs(MONTHS) do
		remapper[m] = idx
	end

	return function (whichmonth)
		return remapper[whichmonth]
	end
end

local which_month_index = fetch_month_index_op()

local function calc_sun_orbit_delta(whichmonth, ecliptic_obliquity)
	local month = which_month_index(whichmonth) - 1
	local day = 30 * month + 15
	local lambda = math.rad(280.46 + 0.9856474 * day);
	return math.asin(math.sin(ecliptic_obliquity) * math.sin(lambda))
end

local function calc_sun_direction(skycomp)
	local latitude = skycomp.latitude
	local whichhour = skycomp.which_hour
	local delta = calc_sun_orbit_delta(skycomp.month, skycomp.ecliptic_obliquity)

	local hh = whichhour * math.pi / 12
	local azimuth = math.atan(
			math.sin(hh), 
			math.cos(hh) * math.cos(latitude) - math.tan(delta) * math.cos(latitude))

	local altitude = math.asin(math.sin(latitude) * math.sin(delta) + 
								math.cos(latitude) * math.cos(delta) * math.cos(hh))

	local rot0 = ms:quaternion(skycomp.updir, azimuth)
	local dir = ms(skycomp.northdir, rot0, "*P")
	local uxd = ms(skycomp.updir, dir, "xP")
	
	local rot1 = ms:quaternion(uxd, altitude)
	
	return ms(dir, rot1, "*P")
end

function ps:init()
	self.northdir =	ms:ref "vector" {1, 0, 0, 0}
	self.updir  = ms:ref "vector" {0, 1, 0, 0}
	self.ecliptic_obliquity = math.rad(23.44)	--the earth's ecliptic obliquity is 23.44

	self.sundir = ms:ref "vector"(calc_sun_direction(self))
	return self
end

local sky_system = ecs.system "sky_system"
sky_system.dependby "primitive_filter_system"

local function fill_procedural_sky_mesh(skyentity)
	local skycomp = skyentity.procedural_sky
	local w, h = skycomp.w, skycomp.h

	local vb = {"ff",}
	local ib = {}

	local w_count, h_count = w - 1, h - 1
	for j=0, h_count do
		for i=0, w_count do
			local x = i / w_count * 2.0 - 1.0
			local y = j / h_count * 2.0 - 1.0
			vb[#vb+1] = x
			vb[#vb+1] = y
		end 
	end

	for j=0, h_count - 1 do
		for i=0, w_count - 1 do
			local lineoffset = w * j
			local nextlineoffset = w*j + w

			ib[#ib+1] = i + lineoffset
			ib[#ib+1] = i + 1 + lineoffset
			ib[#ib+1] = i + nextlineoffset

			ib[#ib+1] = i + 1 + lineoffset
			ib[#ib+1] = i + 1 + nextlineoffset
			ib[#ib+1] = i + nextlineoffset
		end
	end

	local meshcomp = skyentity.mesh

	meshcomp.assetinfo = computil.create_simple_mesh({
		stride = 8, -- "ff"
		{name="POSITION", offset=0, elemtype="FLOAT", elemcount=2},
	}, vb, w * h, ib, #ib)
end

local shader_parameters = {0.02, 3.0, 0.1, 0}

function sky_system:init()
	local skyeid = world:create_entity {
		transform = mu.identity_transform(),
		mesh = {},
		material = computil.assign_material(
			fs.path "/pkg/ant.resources/depiction/materials/sky/procedural/procedural_sky.material",
			{
				uniforms = {
					u_sunDirection = {type="v4", name="sub direction", value = {0, 0, 1, 0}},
					u_sunLuminance = {type="v4", name="sky luminace in RGB color space", value={0, 0, 0, 0}},
					u_skyLuminanceXYZ = {type="v4", name="sky luminance in XYZ color space", value={0, 0, 0, 0}},
					u_parameters = {type="v4", name="parameter include: x=sun size, y=sun bloom, z=exposition, w=time", 
						value=shader_parameters},
					u_perezCoeff = {type="v4", name="Perez coefficients", value = ABCDE},
				}
			}),
		procedural_sky = {
			w = 32, h = 32,
			which_hour 	= 12,	-- high noon
			turbidity 	= 0.5,
			month 		= "June",
			latitude 	= math.rad(50),
		},
		main_view = true,
		can_render = true,
		name = "procedural sky",
	}

	fill_procedural_sky_mesh(world[skyeid])
end

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
	
	return function(time)
		local l,h = binary_search(time)
		if l == h then
			return t[l]
		end

		return ms:lerp(t[l], t[h], mu.ratio(l, h, time))
	end
end

local sun_luminance_fetch = fetch_value_operation(sun_luminance_XYZ)
local sky_luminance_fetch = fetch_value_operation(sky_luminance_XYZ)

local function update_sky_parameters(skyentity)
	local skycomp = skyentity.procedural_sky
	local sky_uniforms = skyentity.material.content[1].properties.uniforms

	local hour = skycomp.which_hour

	sky_uniforms["u_sunDirection"].value 	= skycomp.sundir
	sky_uniforms["u_sunLuminance"].value 	= xyz2rgb(sun_luminance_fetch(hour))
	sky_uniforms["u_skyLuminanceXYZ"].value = ms(sky_luminance_fetch(hour), "P")
	sky_uniforms["u_perezCoeff"].value 		= compute_PerezCoeff(skycomp.turbidity)
	shader_parameters[4] = hour
	sky_uniforms["u_parameters"].value 		= shader_parameters
end

function sky_system:update()
	for _, eid in world:each "procedural_sky" do
		local e = world[eid]
		update_sky_parameters(e)
	end
end


local sun_update_system = ecs.system "sun_update_system"
sun_update_system.dependby "sky_system"
sun_update_system.depend "timesystem"

local timer = import_package "ant.timer"

local function update_hour(skycomp, deltatime, unit)
	unit = unit or 24
	skycomp.which_hour = (skycomp.which_hour + deltatime) % unit
end

function sun_update_system:update()
	for _, eid in world:each "procedural_sky" do
		local e = world[eid]
		local skycomp = e.procedural_sky
		update_hour(skycomp, timer.deltatime)
		calc_sun_direction(skycomp)
	end
end
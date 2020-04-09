local util = {}; util.__index = {}

local renderpkg = import_package "ant.render"
local computil 	= renderpkg.components

local mathpkg	= import_package "ant.math"
local mu,mc		= mathpkg.util, mathpkg.constant

local assetmgr	= import_package "ant.asset"

local fs 		= require "filesystem"

local function fill_procedural_sky_mesh(skyentity)
	local skycomp = skyentity.procedural_sky
	local w, h = skycomp.grid_width, skycomp.grid_height

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

	local meshcomp = skyentity.rendermesh
	meshcomp.reskey = assetmgr.register_resource(fs.path "//res.mesh/procedural_sky.mesh", computil.create_simple_mesh("p2", vb, w * h, ib, #ib))
end

function util.create_procedural_sky(world, settings)
	settings = settings or {}
	local function attached_light(eid)
		if eid then
			return world[eid].serialize
		end
	end
	local material = [[
---
/pkg/ant.resources/depiction/materials/sky/procedural/procedural_sky.material
---
op: replace
path: /properties/uniforms/u_sunDirection
value:
	type: v4
	name: "sub direction"
	value: {0, 0, 1, 0}
---
op: replace
path: /properties/uniforms/u_sunLuminance
value:
	type: v4
	name: "sky luminace in RGB color space"
	value: {0, 0, 0, 0}
---
op: replace
path: /properties/uniforms/u_skyLuminanceXYZ
value:
	type: v4
	name: "sky luminance in XYZ color space"
	value: {0, 0, 0, 0}
---
op: replace
path: /properties/uniforms/u_parameters
value:
	type: v4
	name: "parameter include: x=sun size, y=sun bloom, z=exposition, w=time"
	value: {0, 0, 0, 0}
---
op: replace
path: /properties/uniforms/u_perezCoeff
value:
	type: v4_array
	name: "Perez coefficients"
	value_array:
		{0, 0, 0, 0}
		{0, 0, 0, 0}
		{0, 0, 0, 0}
		{0, 0, 0, 0}
		{0, 0, 0, 0}
]]
    local skyeid = world:create_entity {
		policy = {
			"ant.render|render",
			"ant.sky|procedural_sky",
			"ant.render|name",
		},
		data = {
			transform = {srt=mu.srt()},
			rendermesh = {},
			material = material,
			procedural_sky = {
				grid_width = 32, 
				grid_height = 32,
				attached_sun_light = attached_light(settings.attached_sun_light),
				which_hour 	= settings.whichhour or 12,	-- high noon
				turbidity 	= settings.turbidity or 2.15,
				month 		= settings.whichmonth or "June",
				latitude 	= settings.whichlatitude or math.rad(50),
			},
			can_render = true,
			name = "procedural sky",
		}
	}

	fill_procedural_sky_mesh(world[skyeid])
	return skyeid
end


return util
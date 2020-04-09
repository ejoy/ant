local util = {}; util.__index = {}

local assetmgr = import_package "ant.asset"

local renderpkg = import_package "ant.render"
local computil 	= renderpkg.components

local mathpkg	= import_package "ant.math"
local mu,mc		= mathpkg.util, mathpkg.constant

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

	skyentity.rendermesh = assetmgr.load("//res.mesh/procedural_sky.rendermesh", computil.create_simple_mesh("p2", vb, w * h, ib, #ib))
end

local function create_material(materialpath, uniforms)
	local m = assetmgr.clone(assetmgr.load(materialpath), "/properties/uniforms")
	local u = m.properties.uniforms
	for k, v in pairs(uniforms) do

	end
end

function util.create_procedural_sky(world, settings)
	settings = settings or {}
	local function attached_light(eid)
		if eid then
			return world[eid].serialize
		end
	end
    local skyeid = world:create_entity {
		policy = {
			"ant.render|render",
			"ant.sky|procedural_sky",
			"ant.render|name",
		},
		data = {
			transform = {srt=mu.srt()},
			rendermesh = {},
			material = "/pkg/ant.resources/depiction/materials/sky/procedural/procedural_sky.material",
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

	local sky = world[skyeid]
	local m = assetmgr.clone(sky.material, "/properties/uniforms")
	sky.material = m
	local uniforms = m.properties.uniforms
	for _, n in ipairs{
		"u_sunDirection",
		"u_sunLuminance",
		"u_skyLuminanceXYZ",
		"u_parameters",
		"u_perezCoeff",
	} do
		uniforms[n] = assetmgr.clone(assert(uniforms[n]))
	end

	fill_procedural_sky_mesh(world[skyeid])
	return skyeid
end


return util
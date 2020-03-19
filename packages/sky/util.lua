local util = {}; util.__index = {}

local renderpkg = import_package "ant.render"
local computil 	= renderpkg.components

local mathpkg	= import_package "ant.math"
local mu		= mathpkg.util

local assetpkg	= import_package "ant.asset"
local assetmgr	= assetpkg.mgr

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
    local skyeid = world:create_entity {
		policy = {
			"ant.render|render",
			"ant.sky|procedural_sky",
			"ant.render|name",
		},
		data = {
			transform = {srt=mu.srt()},
			rendermesh = {},
			material = computil.assign_material(
				fs.path "/pkg/ant.resources/depiction/materials/sky/procedural/procedural_sky.material",
				{
					uniforms = {
						u_sunDirection = {type="v4", name="sub direction", value = {0, 0, 1, 0}},
						u_sunLuminance = {type="v4", name="sky luminace in RGB color space", value={0, 0, 0, 0}},
						u_skyLuminanceXYZ = {type="v4", name="sky luminance in XYZ color space", value={0, 0, 0, 0}},
						u_parameters = {type="v4", name="parameter include: x=sun size, y=sun bloom, z=exposition, w=time", 
							value={}},
						u_perezCoeff = {type="v4", name="Perez coefficients", value = {}},
					}
				}),
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
end


return util
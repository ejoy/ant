local mathpkg       = import_package "ant.math"
local mc            = mathpkg.constant

local math3d        = require "math3d"
local bgfx          = require "bgfx"
local rmat          = require "render.material"
local CMATOBJ       = require "cmatobj"


local function texture_value(stage)
	return {stage=stage, value=nil, handle=nil, type='t'}
end

local function buffer_value(stage, access)
	return {stage=stage, access=access, value=nil, type='b'}
end

local function which_uniform_type(mv)
	local vv = math3d.tovalue(mv)
	return #vv == 16 and "m4" or "v4"
end

local function check(properties)
	for k, v in pairs(properties) do
		if v.type == "u" or v.type == "s" then
			local n = 1
			local ut
			if v.stage == nil then
				if type(v.value) == "table" then
					n = #v.value
					ut = which_uniform_type(v.value[1])
				else
					ut = which_uniform_type(v.value)
				end
			else
				ut = "s"
			end

			v.handle = bgfx.create_uniform(k, ut, n)
		end
	end
	return properties
end

local SYS_ATTRIBS = rmat.system_attribs(CMATOBJ, check{
	--camera
	u_eyepos				= {type="u", value=mc.ZERO_PT},
	u_exposure_param		= {type="u", value=math3d.vector(16.0, 0.008, 100.0, 0.0)},
	u_camera_param			= {type="u", value=mc.ZERO},
	--lighting
	u_cluster_size			= {type="u", value=mc.ZERO},
	u_cluster_shading_param	= {type="u", value=mc.ZERO},
	u_light_count			= {type="u", value=mc.ZERO},
	b_light_grids			= buffer_value(10, "r"),
	b_light_index_lists		= buffer_value(11, "r"),
	b_light_info			= buffer_value(12, "r"),
	u_time					= {type="u", value=mc.ZERO},

	--IBL
	u_ibl_param				= {type="u", value=mc.ZERO},
	s_irradiance			= texture_value(5),
	s_prefilter				= texture_value(6),
	s_LUT					= texture_value(7),

	--curve world
	--[[
		u_curveworld_param = (flat, base, exp, amp)
		dirWS = mul(u_invView, dirVS)
		dis = length(u_eyepos-posWS);
		offsetWS = (amp*((dis-flat)/base)^exp) * dirWS
		posWS = posWS + offsetWS
	]]
	u_curveworld_param		= {type="u", value=mc.ZERO},	-- flat distance, base distance, exp, amplification
	u_curveworld_dir		= {type="u", value=mc.ZAXIS},	-- dir in view space

	-- shadow
	--   csm
	u_csm_matrix 		= { type="u",
		value = {
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
		}
	},
	u_csm_split_distances= {type="u", value=mc.ZERO},
	u_depth_scale_offset = {type="u", value=mc.ZERO},
	u_shadow_param1		 = {type="u", value=mc.ZERO},
	u_shadow_param2		 = {type="u", value=mc.ZERO},
	s_shadowmap			 = texture_value(8),

	--   omni
	u_omni_matrix = { type = "u",
		value = {
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
		}
	},

	u_tetra_normal_Green	= {type="u", value=mc.ZERO},
	u_tetra_normal_Yellow	= {type="u", value=mc.ZERO},
	u_tetra_normal_Blue		= {type="u", value=mc.ZERO},
	u_tetra_normal_Red		= {type="u", value=mc.ZERO},

	s_omni_shadowmap	= texture_value(9),
})

return SYS_ATTRIBS
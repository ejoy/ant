local ecs			= ...

local mathpkg       = import_package "ant.math"
local mc            = mathpkg.constant

local math3d        = require "math3d"
local bgfx          = require "bgfx"
local texmgr		= require "texture_mgr"
local rmat          = ecs.clibs "render.material"

local setting		= import_package "ant.settings".setting
local irradianceSH_bandnum<const> = setting:get "graphic/ibl/irradiance_bandnum"

local function texture_value(stage, defaultid)
	return {stage=stage, value=defaultid, handle=nil, type='t'}
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
		if v.type == "u" or v.type == "t" then
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

local function default_irradiance_SH_value()
	if irradianceSH_bandnum == nil then
		return mc.ZERO
	end
	if irradianceSH_bandnum == 2 then
		return {
			mc.ZERO,
			mc.ZERO, mc.ZERO, mc.ZERO,
		}
	elseif irradianceSH_bandnum == 3 then
		return {
			mc.ZERO,
			mc.ZERO, mc.ZERO, mc.ZERO,
			mc.ZERO, mc.ZERO, mc.ZERO, mc.ZERO, mc.ZERO,
		}
	end
end

local function uniform_value(value)
	return {type='u', value=value}
end

local DEFAULT_TEXCUBE_ID<const> = texmgr.default_textureid "TEXCUBE"
local DEFAULT_TEX2D_ID<const> = texmgr.default_textureid "TEX2D"

local SYS_ATTRIBS = rmat.system_attribs(check{
	--camera
	u_eyepos				= uniform_value(mc.ZERO_PT),
	u_exposure_param		= uniform_value(math3d.vector(16.0, 0.008, 100.0, 0.0)),
	u_camera_param			= uniform_value(mc.ZERO),
	--lighting
	u_cluster_size			= uniform_value(mc.ZERO),
	u_cluster_shading_param	= uniform_value(mc.ZERO),
	u_light_count			= uniform_value(mc.ZERO),
	b_light_grids			= buffer_value(10, "r"),
	b_light_index_lists		= buffer_value(11, "r"),
	b_light_info			= buffer_value(12, "r"),
	u_indirect_modulate_color=uniform_value(mc.ONE_PT),
	u_time					= uniform_value(mc.ZERO),

	--IBL
	u_ibl_param				= uniform_value(mc.ZERO),
	u_irradianceSH			= uniform_value(default_irradiance_SH_value()),
	s_irradiance			= texture_value(5, DEFAULT_TEXCUBE_ID),
	s_prefilter				= texture_value(6, DEFAULT_TEXCUBE_ID),
	s_LUT					= texture_value(7, DEFAULT_TEX2D_ID),

	--curve world
	--[[
		u_curveworld_param = (flat, base, exp, amp)
		dirWS = mul(u_invView, dirVS)
		dis = length(u_eyepos-posWS);
		offsetWS = (amp*((dis-flat)/base)^exp) * dirWS
		posWS = posWS + offsetWS
		u_curveworld_param		= uniform_value(mc.ZERO),	-- flat distance, base distance, exp, amplification
		u_curveworld_dir		= uniform_value(mc.ZAXIS),	-- dir in view space
	]]
	-- shadow
	--   csm
	u_csm_matrix 		= uniform_value{
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
		},

	u_csm_split_distances= uniform_value(mc.ZERO),
	u_depth_scale_offset = uniform_value(mc.ZERO),
	u_shadow_param1		 = uniform_value(mc.ZERO),
	u_shadow_param2		 = uniform_value(mc.ZERO),

	s_shadowmap			 = texture_value(8, DEFAULT_TEX2D_ID),
	--u_main_camera_matrix = uniform_value(mc.IDENTITY_MAT),
	--   omni
	u_omni_matrix = uniform_value{
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
		},

	u_tetra_normal_Green	= uniform_value(mc.ZERO),
	u_tetra_normal_Yellow	= uniform_value(mc.ZERO),
	u_tetra_normal_Blue		= uniform_value(mc.ZERO),
	u_tetra_normal_Red		= uniform_value(mc.ZERO),

	--s_omni_shadowmap	= texture_value(9),

	s_ssao				= texture_value(9, DEFAULT_TEX2D_ID),
	--postprocess
	u_reverse_pos_param	= uniform_value(mc.ZERO),
})

return SYS_ATTRIBS
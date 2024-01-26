local bgfx          = require "bgfx"

local matpkg		= import_package "ant.material"
local matutil 		= matpkg.util
local setting		= import_package "ant.settings"
local irradianceSH_bandnum<const> = setting:get "graphic/ibl/irradiance_bandnum"

local function texture_value(stage, samplertype)
	return {stage=stage, value=0, handle=nil, type='t', stype=samplertype}
end

local function buffer_value(stage, access)
	return {stage=stage, access=access, value=nil, type='b'}
end

local function default_irradiance_SH_utype()
	if irradianceSH_bandnum == 2 then 
		return "v3"
	end
	if irradianceSH_bandnum == 3 then
		return "v7"
	end
	return "v1"
end

local ZERO<const>, ZERO_PT<const> = matutil.ZERO, matutil.ZERO_PT

local function default_irradiance_SH_value()
	--See, ibl.lua:update_SH_attributes
	if irradianceSH_bandnum == nil then
		return ZERO
	end
	if irradianceSH_bandnum == 2 then
		return matutil.append_values(ZERO, ZERO, ZERO)
	end
	if irradianceSH_bandnum == 3 then
		return matutil.append_values(
			ZERO,
			ZERO, ZERO, ZERO,
			ZERO, ZERO, ZERO)
	end
end

local function uniform_value(value, utype)
	utype = utype or "v1"
	return {type='u', value=value, utype=utype}
end

local SYS_ATTRIBS = {
	--camera
	u_eyepos				= uniform_value(ZERO_PT),
	u_exposure_param		= uniform_value(matutil.v4(6.0, 0.008, 100.0, 0.0)),
	u_camera_param			= uniform_value(ZERO),
	--lighting
	u_cluster_size			= uniform_value(ZERO),
	u_cluster_shading_param	= uniform_value(ZERO),
	u_light_count			= uniform_value(ZERO),
	b_light_grids			= buffer_value(10, "r"),
	b_light_index_lists		= buffer_value(11, "r"),
	b_light_info			= buffer_value(12, "r"),
	u_indirect_modulate_color=uniform_value(matutil.ONE_PT),
	u_time					= uniform_value(ZERO),

	--IBL
	u_ibl_param				= uniform_value(ZERO),
	u_irradianceSH			= uniform_value(default_irradiance_SH_value(), default_irradiance_SH_utype()),
	s_irradiance			= texture_value(5, "SAMPLERCUBE"),
	s_prefilter				= texture_value(6, "SAMPLERCUBE"),
	s_LUT					= texture_value(7, "SAMPLER2D"),

	-- shadow
	--   csm
	u_csm_matrix 		= uniform_value(matutil.append_values(
			matutil.IDENTITY_MAT,
			matutil.IDENTITY_MAT,
			matutil.IDENTITY_MAT,
			matutil.IDENTITY_MAT), "m4"),

	u_csm_split_distances= uniform_value(ZERO),
	u_depth_scale_offset = uniform_value(ZERO),
	u_shadow_param1		 = uniform_value(ZERO),
	u_soft_shadow_param	 = uniform_value(ZERO),

	s_shadowmap			 = texture_value(8, "SAMPLER2D"),
	--u_main_camera_matrix = uniform_value(mc.IDENTITY_MAT),
	--   omni
	u_omni_matrix = uniform_value(matutil.append_values(
			matutil.IDENTITY_MAT,
			matutil.IDENTITY_MAT,
			matutil.IDENTITY_MAT,
			matutil.IDENTITY_MAT), "m4"),

	u_tetra_normal_Green	= uniform_value(ZERO),
	u_tetra_normal_Yellow	= uniform_value(ZERO),
	u_tetra_normal_Blue		= uniform_value(ZERO),
	u_tetra_normal_Red		= uniform_value(ZERO),

	--s_omni_shadowmap	= texture_value(9),

	s_ssao				= texture_value(9, "SAMPLER2D"),
	--postprocess
	u_reverse_pos_param	= uniform_value(ZERO),
	u_jitter            = uniform_value(ZERO),

	--- direct specular D F V
	s_direct_specular = texture_value(13, "SAMPLER2D"),
}

return SYS_ATTRIBS
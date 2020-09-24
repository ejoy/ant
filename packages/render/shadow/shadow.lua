local ecs = ...
local world = ecs.world

local setting	= import_package "ant.settings".setting

local math3d	= require "math3d"
local hwi 		= require "hardware_interface"

local fbmgr		= require "framebuffer_mgr"
local samplerutil = require "sampler"

local function calc_bias_matrix()
	-- topleft origin and homogeneous depth matrix
	local m = {
		0.5, 0.0, 0.0, 0.0,
		0.0, -0.5, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		0.5, 0.5, 0.0, 1.0,
	}

	local caps = hwi.get_caps()
	if caps.originBottomLeft then
		m[6] = -m[6]
	end
	
	if caps.homogeneousDepth then
		m[11], m[15] = 0.5, 0.5
	end

	return math3d.ref(math3d.matrix(m))
end

local sm_bias_matrix = calc_bias_matrix()

local homogeneous_depth_scale_offset = math3d.ref(math3d.vector(0.5, 0.5, 0.0, 0.0))
local normal_depth_scale_offset = math3d.ref(math3d.vector(1.0, 0.0, 0.0, 0.0))

local scale_offset = hwi.get_caps().homogeneousDepth and homogeneous_depth_scale_offset or normal_depth_scale_offset

local shadowcfg = setting:data().graphic.shadow

local function gen_ratios(distances)
	local pre_dis = 0
	local ratios = {}
	for i=1, #distances do
		local dis = distances[i]
		ratios[#ratios+1] = {pre_dis, dis}
		pre_dis = dis
	end
	ratios[#ratios+1] = {pre_dis, 1.0}
	return ratios
end

local function get_render_buffers(width, height, depth_type)
	if depth_type == "linear" then
		local flags = samplerutil.sampler_flag {
			RT="RT_ON",
			MIN="LINEAR",
			MAG="LINEAR",
			U="CLAMP",
			V="CLAMP",
		}

		return {
			fbmgr.create_rb{
				format = "RGBA8",
				w=width,
				h=height,
				layers=1,
				flags=flags,
			},
			fbmgr.create_rb {
				format = "D24S8",
				w=width,
				h=height,
				layers=1,
				flags=flags,
			},
		}

	end

	return {
		fbmgr.create_rb{
			format = "D32F",
			w=width,
			h=height,
			layers=1,
			flags=samplerutil.sampler_flag{
				RT="RT_ON",
				MIN="LINEAR",
				MAG="LINEAR",
				U="CLAMP",
				V="CLAMP",
				COMPARE="COMPARE_LEQUAL",
				BOARD_COLOR="0",
			},
		}
	}
end

local function shadow_color()
	local c = {1, 1, 1, 1}
	for idx, v in ipairs(shadowcfg.color) do
		c[idx] = v
	end

	return c
end

local csm_setting = {
	depth_type		= shadowcfg.type,
	shadowmap_size	= shadowcfg.size,
	split_num		= shadowcfg.split_num,
	shadow_param	= {shadowcfg.bias, shadowcfg.normal_offset, 1/shadowcfg.size, 0},
    color			= math3d.ref(math3d.vector(shadow_color())),
    --stabilize		= shadowcfg.stabilize,
	split_frustums	= {nil, nil, nil, nil},
	fb_index		= fbmgr.create(get_render_buffers(shadowcfg.size * shadowcfg.split_num, shadowcfg.size, shadowcfg.type))
}

if shadowcfg.split_lamada then
	csm_setting.split_lamada = shadowcfg.split_lamada and math.max(0, math.min(1, shadowcfg.split_lamada)) or nil
else
	local ratio_list
	if shadowcfg.split_ratios then
		if #shadowcfg.split_ratios ~= (csm_setting.split_num - 1)  then
			error(("#split_ratios == split_num - 1: %d, %d"):format(#shadowcfg.split_ratios, csm_setting.split_num))
		end

		ratio_list = shadowcfg.split_ratios
	else
		ratio_list = {0.18, 0.35, 0.65}
		csm_setting.split_num = 4
	end

	csm_setting.split_ratios = gen_ratios(ratio_list)
end

local ishadow = ecs.interface "ishadow"

function ishadow.setting()
	return csm_setting
end

function ishadow.shadow_depth_scale_offset()
	return scale_offset
end

local crop_matrices = {}

local spiltunit = 1 / csm_setting.split_num
local function calc_crop_matrix(csm_idx)
	local offset = spiltunit * (csm_idx - 1)
	return math3d.matrix(
		spiltunit, 0.0, 0.0, 0.0,
		0.0, 1.0, 0.0, 0.0, 
		0.0, 0.0, 1.0, 0.0,
		offset, 0.0, 0.0, 1.0)
end

for csm_idx=1, csm_setting.split_num do
	local vp_crop = calc_crop_matrix(csm_idx)
	crop_matrices[#crop_matrices+1] = math3d.ref(math3d.mul(vp_crop, sm_bias_matrix))
end


function ishadow.crop_matrix(csm_index)
	return crop_matrices[csm_index]
end

function ishadow.fb_index()
	return csm_setting.fb_index
end

function ishadow.depth_type()
	return csm_setting.depth_type
end

function ishadow.bias()
	return csm_setting.shadow_param[1]
end

function ishadow.normal_offset()
	return csm_setting.shadow_param[2]
end

function ishadow.shadow_param()
	return csm_setting.shadow_param
end

function ishadow.color()
	return csm_setting.color
end

local function split_new_frustum(view_frustum, n, f)
	local frustum = {}
	for k, v in pairs(view_frustum) do
		frustum[k] = v
	end

	frustum.n, frustum.f = n, f
	return frustum
end

function ishadow.split_frustums()
	return csm_setting.split_frustums
end

function ishadow.shadowmap_size()
	return csm_setting.shadowmap_size
end

function ishadow.calc_split_frustums(view_frustum)
	local lambda = csm_setting.split_lamada
	local split_frustums = csm_setting.split_frustums
	local view_nearclip, view_farclip = view_frustum.n, view_frustum.f
	local clip_range = view_farclip - view_nearclip
	local split_num = csm_setting.split_num

	local function calc_clip(r)
		return view_nearclip + clip_range * r
	end
	
	if lambda then
		local ratio = view_farclip / view_nearclip;
		local last_clip = view_nearclip
		for i=1, split_num do
			local p = i / split_num
			local log = view_nearclip * (ratio ^ p);
			local uniform = calc_clip(p)
			local new_far_clip = lambda * (log - uniform) + uniform;

			split_frustums[i] = split_new_frustum(view_frustum, last_clip, new_far_clip)
			last_clip = new_far_clip
		end
	else
		for i=1, split_num do
			local ratio = csm_setting.split_ratios[i]
			local near_clip, far_clip = calc_clip(ratio[1]), calc_clip(ratio[2])
			split_frustums[i] = split_new_frustum(view_frustum, near_clip, far_clip)
		end
	end
	return split_frustums
end

function ishadow.split_num()
	return csm_setting.split_num
end

return ishadow
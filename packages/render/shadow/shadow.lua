local ecs = ...
local world = ecs.world
local w = world.w

local setting	= import_package "ant.settings".setting
local hwi 		= import_package "ant.hwi"
local math3d	= require "math3d"

local viewidmgr = require "viewid_mgr"

local bgfx		= require "bgfx"

local fbmgr		= require "framebuffer_mgr"
local samplerutil = require "sampler"
local shadowcommon=require "shadow.common"

local sm_bias_matrix = shadowcommon.sm_bias_matrix

local homogeneous_depth_scale_offset = math3d.ref(math3d.vector(0.5, 0.5, 0.0, 0.0))
local normal_depth_scale_offset = math3d.ref(math3d.vector(1.0, 0.0, 0.0, 0.0))

local scale_offset = hwi.get_caps().homogeneousDepth and homogeneous_depth_scale_offset or normal_depth_scale_offset

local shadowcfg = setting:data().graphic.shadow

local function get_render_buffers(width, height)
	return {
		rbidx=fbmgr.create_rb{
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
	local c = {0, 0, 0, 1}
	for idx, v in ipairs(shadowcfg.color) do
		c[idx] = v
	end

	return c
end

local csm_setting = {
	shadowmap_size	= shadowcfg.size,
	shadow_param	= {shadowcfg.bias, shadowcfg.normal_offset, 1/shadowcfg.size, 0},
    color			= math3d.ref(math3d.vector(shadow_color())),
    --stabilize		= shadowcfg.stabilize,
	split_num		= shadowcfg.split_num,
	cross_delta		= shadowcfg.cross_delta or 0.005,
	split_weight	= shadowcfg.split_weight or 0.5,
	split_frustums	= {nil, nil, nil, nil},
	fb_index		= fbmgr.create(get_render_buffers(shadowcfg.size * shadowcfg.split_num, shadowcfg.size)),
}

local function gen_ratios(distances)
	local pre_dis = 0
	local ratios = {}
	for i=1, #distances do
		local dis = distances[i] * (1.0+csm_setting.cross_delta)
		ratios[#ratios+1] = {pre_dis, dis}
		pre_dis = dis
	end
	ratios[#ratios+1] = {pre_dis, 1.0}
	return ratios
end

if shadowcfg.split_weight then
	csm_setting.split_weight = shadowcfg.split_weight and math.max(0, math.min(1, shadowcfg.split_weight)) or nil
else
	local ratio_list
	
	if shadowcfg.split_ratios then
		local n =csm_setting.split_num
		if #shadowcfg.split_ratios ~= (n - 1)  then
			error(("#split_ratios == split_num - 1: %d, %d"):format(#shadowcfg.split_ratios, n))
		end

		ratio_list = shadowcfg.split_ratios
	else
		ratio_list = {0.08, 0.18, 0.45}
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
	local split_weight = csm_setting.split_weight
	local frustums = csm_setting.split_frustums
	local view_nearclip, view_farclip = view_frustum.n, view_frustum.f
	local clip_range = view_farclip - view_nearclip
	local split_num = csm_setting.split_num

	if split_weight then
		local ratio = view_farclip/view_nearclip
		local num_sclies = split_num*2

		local nearclip = view_nearclip
		local cross_multipler = (1.0+csm_setting.cross_delta)
		for i=1, split_num do
			local idx = (i-1)*2
			local si = (idx+1) / num_sclies
			local farclip = split_weight*(view_nearclip*(ratio^si)) + (1-split_weight)*(view_nearclip + clip_range*si)
			frustums[i] = split_new_frustum(view_frustum, nearclip, farclip)
			nearclip = farclip * cross_multipler
		end
	else
		local function calc_clip(r)
			return view_nearclip + clip_range * r
		end

		for i=1, split_num do
			local ratio = csm_setting.split_ratios[i]
			local near_clip, far_clip = calc_clip(ratio[1]), calc_clip(ratio[2])
			frustums[i] = split_new_frustum(view_frustum, near_clip, far_clip)
		end
	end
	return frustums
end

function ishadow.split_num()
	return csm_setting.split_num
end

return ishadow
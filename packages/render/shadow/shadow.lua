local ecs = ...
local world = ecs.world
local w = world.w

local setting	= import_package "ant.settings".setting
local mathpkg	= import_package "ant.math"
local mu		= mathpkg.util
local math3d	= require "math3d"

local bgfx		= require "bgfx"

local fbmgr		= require "framebuffer_mgr"
local sampler	= require "sampler"

local sm_bias_matrix = mu.calc_texture_matrix()

local shadowcfg = setting:data().graphic.shadow

local function shadow_color()
	local c = {0, 0, 0, 1}
	for idx, v in ipairs(shadowcfg.color) do
		c[idx] = v
	end

	return c
end

bgfx.set_palette_color(0, 0.0, 0.0, 0.0, 0.0)
local csm_setting = {
	shadowmap_size	= shadowcfg.size,
	shadow_param	= {shadowcfg.bias, shadowcfg.normal_offset, 1/shadowcfg.size, 0.00012},
    color			= math3d.ref(math3d.vector(shadow_color())),
    --stabilize		= shadowcfg.stabilize,
	split_num		= shadowcfg.split_num,
	split_frustums	= {nil, nil, nil, nil},
}

local function gen_ratios(distances)
	local pre_dis = 0
	local ratios = {}
	for i=1, #distances do
		local dis = math.min(1.0, distances[i] * (1.0+csm_setting.cross_delta))
		ratios[#ratios+1] = {pre_dis, dis}
		pre_dis = dis
	end
	ratios[#ratios+1] = {pre_dis, 1.0}
	return ratios
end


if shadowcfg.split_ratios then
	if csm_setting.split_num then
		if #shadowcfg.split_ratios ~= (csm_setting.split_num - 1)  then
			error(("#split_ratios == split_num - 1: %d, %d"):format(#shadowcfg.split_ratios, csm_setting.split_num))
		end
	else
		csm_setting.split_num = #shadowcfg.split_ratios
	end
	csm_setting.split_ratios = shadowcfg.split_ratios
else
	csm_setting.cross_delta	= shadowcfg.cross_delta or 0.25
	if shadowcfg.split_weight then
		csm_setting.split_num	= shadowcfg.split_num
		csm_setting.split_weight= math.max(0, math.min(1, shadowcfg.split_weight))
	else
		csm_setting.split_num = 4
		csm_setting.split_ratios = {
<<<<<<< HEAD
			{0.0,0.05},
			{0.04,0.25},
			{0.2,0.45},
			{0.40,0.85}
		}
		-- csm_setting.split_ratios = gen_ratios{0.3, 0.48, 0.85}
=======
			{0.05, 0.25},
			{0.23, 0.48},
			{0.45, 0.65},
			{0.60, 0.85},
		}
>>>>>>> 9ebbe7d18a9a6ddca474b98718ec9480b4de0623
	end
end

assert(csm_setting.split_num ~= nil)

csm_setting.fb_index = fbmgr.create{
	rbidx=fbmgr.create_rb{
		format = "D32F",
		w=csm_setting.shadowmap_size * csm_setting.split_num,
		h=csm_setting.shadowmap_size,
		layers=1,
		flags=sampler{
			RT="RT_ON",
			MIN="LINEAR",
			MAG="LINEAR",
			U="BORDER",
			V="BORDER",
			COMPARE="COMPARE_GEQUAL",
			BOARD_COLOR="0",
		},
	}
}

local ishadow = ecs.interface "ishadow"

function ishadow.setting()
	return csm_setting
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

function ishadow.sm_bias_matrix()
	return sm_bias_matrix
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
	--local split_weight = 0.75
	local frustums = csm_setting.split_frustums
	local view_nearclip, view_farclip = view_frustum.n, view_frustum.f
	local clip_range = view_farclip - view_nearclip
	local split_num = csm_setting.split_num

	if split_weight then
 		local ratio = view_farclip/view_nearclip
		local num_sclies = split_num*2
		local nearclip = view_nearclip
		local farclip
		local cross_multipler = (1.0+csm_setting.cross_delta)
		local nn=2
		local ff=1
--[[ 		for i=1, split_num do
			local idx = (i-1)*2
			local si = (idx+1) / num_sclies
			local farclip = split_weight*(view_nearclip*(ratio^si)) + (1-split_weight)*(view_nearclip + clip_range*si)
			frustums[i] = split_new_frustum(view_frustum, nearclip, farclip)
			nearclip = farclip * 1.005
		end  ]]
		while nn < num_sclies do
			local si = ff / num_sclies
			farclip = split_weight*(view_nearclip*(ratio^si)) + (1-split_weight)*(view_nearclip + clip_range*si)
			frustums[nn/2] = split_new_frustum(view_frustum, nearclip, farclip)
			nearclip = farclip * cross_multipler
			nn = nn + 2
			ff = ff + 2
		end
		farclip = view_farclip
		frustums[nn/2] = split_new_frustum(view_frustum, nearclip, farclip)

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
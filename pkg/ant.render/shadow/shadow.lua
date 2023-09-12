local ecs 	= ...
local world = ecs.world
local w 	= world.w

local setting	= import_package "ant.settings"
local mathpkg	= import_package "ant.math"
local mu		= mathpkg.util
local math3d	= require "math3d"

local bgfx		= require "bgfx"

local fbmgr		= require "framebuffer_mgr"
local sampler   = import_package "ant.render.core".sampler

local shadowcfg = {
	color = setting:get "graphic/shadow/color",
	depth_multiplier = setting:get "graphic/shadow/depth_multiplier",
	enable = setting:get "graphic/shadow/enable",
	far_offset = setting:get "graphic/shadow/far_offset",
	min_variance = setting:get "graphic/shadow/min_variance",
	normal_offset = setting:get "graphic/shadow/normal_offset",
	size = setting:get "graphic/shadow/size",
	split_lamada = setting:get "graphic/shadow/split_lamada",
	split_num = setting:get "graphic/shadow/split_num",
	height = setting:get "graphic/shadow/height",
	split_ratios = setting:get "graphic/shadow/split_ratios",
	type = setting:get "graphic/shadow/type",
}

bgfx.set_palette_color(0, 0.0, 0.0, 0.0, 0.0)

shadowcfg.shadowmap_size	= shadowcfg.size
shadowcfg.shadow_param		= math3d.ref(math3d.vector(0, shadowcfg.min_variance or 0.0, 1/shadowcfg.size, shadowcfg.depth_multiplier or 1.0))
shadowcfg.shadow_param2		= math3d.ref(math3d.vector(shadowcfg.color[1], shadowcfg.color[2], shadowcfg.color[3], shadowcfg.normal_offset))
shadowcfg.split_frustums	= {nil, nil, nil, nil}

if not shadowcfg.height then shadowcfg.height = 5 end
if not shadowcfg.min_variance then shadowcfg.min_variance = 0.012 end
if not shadowcfg.depth_multiplier then shadowcfg.depth_multiplier = 1000 end
if not shadowcfg.normal_offset then shadowcfg.normal_offset = 0.012 end
if not shadowcfg.far_offset then shadowcfg.far_offset = 0 end
if shadowcfg.split_ratios then
	if shadowcfg.split_num then
		if #shadowcfg.split_ratios ~= (shadowcfg.split_num)  then
			error(("#split_ratios == split_num - 1: %d, %d"):format(#shadowcfg.split_ratios, shadowcfg.split_num))
		end
	else
		shadowcfg.split_num = #shadowcfg.split_ratios
	end
	shadowcfg.split_ratios = shadowcfg.split_ratios
else
	shadowcfg.cross_delta	= shadowcfg.cross_delta or 0.00
	if shadowcfg.split_weight then
		shadowcfg.split_num	= shadowcfg.split_num
		shadowcfg.split_weight= math.max(0, math.min(1, shadowcfg.split_weight))
	else
		shadowcfg.split_num = 4
 		shadowcfg.split_ratios = {
 			{0.00,0.1},
			{0.1,0.30},
			{0.3,0.40},
			{0.4,0.68} 
		}
	end
end


assert(shadowcfg.split_num ~= nil)

shadowcfg.fb_index = fbmgr.create(
	{
		rbidx=fbmgr.create_rb{
			format = "D32F",
			w=shadowcfg.shadowmap_size * shadowcfg.split_num,
			h=shadowcfg.shadowmap_size,
			layers=1,
			flags=sampler{
				RT="RT_ON",
				MIN="POINT",
				MAG="POINT",
				U="BORDER",
				V="BORDER",
				COMPARE="COMPARE_GEQUAL",
				BOARD_COLOR="0",
			},
		}
	}
)

--[[ shadowcfg.sqfb_index = fbmgr.create{
	sqrbidx = fbmgr.create_rb{
		format = "R16F",
		w=shadowcfg.shadowmap_size * shadowcfg.split_num,
		h=shadowcfg.shadowmap_size,
		layers=1,
		flags=sampler{
			MIN="POINT",
			MAG="POINT",
			U="CLAMP",
			V="CLAMP",
			RT="RT_ON",
		}
	}
}
 ]]



local ishadow = {}

function ishadow.setting()
	return shadowcfg
end

local crop_matrices = {}

do
	local spiltunit = 1 / shadowcfg.split_num
	local function calc_crop_matrix(csm_idx)
		local offset = spiltunit * (csm_idx - 1)
		return math3d.matrix(
			spiltunit, 0.0, 0.0, 0.0,
			0.0, 1.0, 0.0, 0.0, 
			0.0, 0.0, 1.0, 0.0,
			offset, 0.0, 0.0, 1.0)
	end

	local sm_bias_matrix = mu.calc_texture_matrix()
	for csm_idx=1, shadowcfg.split_num do
		local vp_crop = calc_crop_matrix(csm_idx)
		crop_matrices[#crop_matrices+1] = math3d.ref(math3d.mul(vp_crop, sm_bias_matrix))
	end
end

function ishadow.crop_matrix(csm_index)
	return crop_matrices[csm_index]
end

function ishadow.fb_index()
	return shadowcfg.fb_index
end

--[[ function ishadow.sqfb_index()
	return shadowcfg.sqfb_index
end ]]

function ishadow.shadow_param()
	return shadowcfg.shadow_param
end

function ishadow.shadow_param2()
	return shadowcfg.shadow_param2
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
	return shadowcfg.split_frustums
end

function ishadow.shadowmap_size()
	return shadowcfg.shadowmap_size
end

function ishadow.calc_split_frustums(view_frustum)
	local split_weight = shadowcfg.split_weight
	local frustums = shadowcfg.split_frustums
	local view_nearclip, view_farclip = view_frustum.n, view_frustum.f
	local clip_range = view_farclip - view_nearclip
	local split_num = shadowcfg.split_num

	if split_weight then
 		local ratio = view_farclip/view_nearclip
		local num_sclies = split_num*2
		local nearclip = view_nearclip
		local farclip
		local cross_multipler = (1.0+shadowcfg.cross_delta)
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
			nearclip = farclip / cross_multipler
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
			local ratio = shadowcfg.split_ratios[i]
			local near_clip, far_clip = calc_clip(ratio[1]), calc_clip(ratio[2])
			frustums[i] = split_new_frustum(view_frustum, near_clip, far_clip)
		end
	end
	return frustums
end

function ishadow.split_num()
	return shadowcfg.split_num
end

return ishadow

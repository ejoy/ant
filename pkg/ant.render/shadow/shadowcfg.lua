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

local SHADOW_CFG = {
	color				= setting:get "graphic/shadow/color",
	depth_multiplier	= setting:get "graphic/shadow/depth_multiplier" or 1000,
	enable				= setting:get "graphic/shadow/enable",
	far_offset			= setting:get "graphic/shadow/far_offset"		or 0,
	min_variance		= setting:get "graphic/shadow/min_variance"		or 0.012,
	normal_offset		= setting:get "graphic/shadow/normal_offset"	or 0.012,
	shadowmap_size		= setting:get "graphic/shadow/size",
	split_lamada		= setting:get "graphic/shadow/split_lamada",
	split_num			= setting:get "graphic/shadow/split_num",
	height				= setting:get "graphic/shadow/height",
	split_ratios		= setting:get "graphic/shadow/split_ratios",
	cross_delta			= setting:get "graphic/shadow/cross_delta"		or 0,
	type				= setting:get "graphic/shadow/type",
}

bgfx.set_palette_color(0, 0.0, 0.0, 0.0, 0.0)

SHADOW_CFG.shadow_param		= math3d.ref(math3d.vector(0, SHADOW_CFG.min_variance, 1/SHADOW_CFG.shadowmap_size, SHADOW_CFG.depth_multiplier or 1.0))
SHADOW_CFG.shadow_param2	= math3d.ref(math3d.vector(SHADOW_CFG.color[1], SHADOW_CFG.color[2], SHADOW_CFG.color[3], SHADOW_CFG.normal_offset))
SHADOW_CFG.split_frustums	= {nil, nil, nil, nil}

if SHADOW_CFG.split_ratios then
	if SHADOW_CFG.split_num then
		if #SHADOW_CFG.split_ratios ~= (SHADOW_CFG.split_num)  then
			error(("#split_ratios == split_num - 1: %d, %d"):format(#SHADOW_CFG.split_ratios, SHADOW_CFG.split_num))
		end
	else
		SHADOW_CFG.split_num = #SHADOW_CFG.split_ratios
	end
else
	if SHADOW_CFG.split_weight then
		SHADOW_CFG.split_num	= assert(SHADOW_CFG.split_num)
		SHADOW_CFG.split_weight= math.max(0, math.min(1, SHADOW_CFG.split_weight))
	else
		SHADOW_CFG.split_num = 4
 		SHADOW_CFG.split_ratios = {
 			{0.00,0.1},
			{0.1,0.30},
			{0.3,0.40},
			{0.4,0.68} 
		}
	end
end


assert(SHADOW_CFG.split_num ~= nil)

SHADOW_CFG.fb_index = fbmgr.create(
	{
		rbidx=fbmgr.create_rb{
			format = "D32F",
			w=SHADOW_CFG.shadowmap_size * SHADOW_CFG.split_num,
			h=SHADOW_CFG.shadowmap_size,
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

--[[ SHADOW_CFG.sqfb_index = fbmgr.create{
	sqrbidx = fbmgr.create_rb{
		format = "R16F",
		w=SHADOW_CFG.shadowmap_size * SHADOW_CFG.split_num,
		h=SHADOW_CFG.shadowmap_size,
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
	return SHADOW_CFG
end

local crop_matrices = {}

do
	local spiltunit = 1 / SHADOW_CFG.split_num
	local function calc_crop_matrix(csm_idx)
		local offset = spiltunit * (csm_idx - 1)
		return math3d.matrix(
			spiltunit, 0.0, 0.0, 0.0,
			0.0, 1.0, 0.0, 0.0, 
			0.0, 0.0, 1.0, 0.0,
			offset, 0.0, 0.0, 1.0)
	end

	local sm_bias_matrix = mu.calc_texture_matrix()
	for csm_idx=1, SHADOW_CFG.split_num do
		local vp_crop = calc_crop_matrix(csm_idx)
		crop_matrices[#crop_matrices+1] = math3d.ref(math3d.mul(vp_crop, sm_bias_matrix))
	end
end

function ishadow.crop_matrix(csm_index)
	return crop_matrices[csm_index]
end

function ishadow.fb_index()
	return SHADOW_CFG.fb_index
end

--[[ function ishadow.sqfb_index()
	return SHADOW_CFG.sqfb_index
end ]]

function ishadow.shadow_param()
	return SHADOW_CFG.shadow_param
end

function ishadow.shadow_param2()
	return SHADOW_CFG.shadow_param2
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
	return SHADOW_CFG.split_frustums
end

function ishadow.shadowmap_size()
	return SHADOW_CFG.shadowmap_size
end

function ishadow.calc_split_frustums(view_frustum)
	local split_weight = SHADOW_CFG.split_weight
	local frustums = SHADOW_CFG.split_frustums
	local view_nearclip, view_farclip = view_frustum.n, view_frustum.f
	local clip_range = view_farclip - view_nearclip
	local split_num = SHADOW_CFG.split_num

	if split_weight then
 		local ratio = view_farclip/view_nearclip
		local num_sclies = split_num*2
		local nearclip = view_nearclip
		local farclip
		local cross_multipler = (1.0+SHADOW_CFG.cross_delta)
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
			local ratio = SHADOW_CFG.split_ratios[i]
			local near_clip, far_clip = calc_clip(ratio[1]), calc_clip(ratio[2])
			frustums[i] = split_new_frustum(view_frustum, near_clip, far_clip)
		end
	end
	return frustums
end

function ishadow.split_num()
	return SHADOW_CFG.split_num
end

function ishadow.calc_uniform_split_positions()
	local sn = SHADOW_CFG.split_num
	local positions = {1.0}
	for c=1, sn-1 do
		positions[#positions+1] = c / sn
	end
	return positions
end

local function log_split(num, c, n, f)
	local base = f/n
	local e =  c/num
	return ((n * (base ^ e))-n) / (f-n)
end

--near&far are view camera's  near & far
function ishadow.calc_log_split_positions(near, far)
	local positions = {1.0}
	local sn = SHADOW_CFG.split_num
	for c=1, sn-1 do
		positions[#positions+1] = log_split(c, near, far)
	end
	return positions
end

function ishadow.calc_split_positions(near, far)
	local sn = SHADOW_CFG.split_num
	local positions = {1.0}
	local lambda = SHADOW_CFG.split_lamada
	for c=1, sn-1 do
		local us = c / sn
		local ls = log_split(sn, c, near, far)
		positions[c] = lambda * ls + (1.0 - lambda) * us
	end
	return positions
end

function ishadow.split_positions_to_ratios(positions)
	local ratios = {}
	local start = 0.0
	for i=1, #positions do
		ratios[#ratios+1] = {start, positions[i]}
		start = positions[i]
	end

	return ratios
end

local function calc_viewspace_z(n, f, r)
	return n + (f-n) * r
end

local function create_sub_viewfrustum(zn, zf, sr, viewfrustum)
	return {
		n = calc_viewspace_z(zn, zf, sr[1]),
		f = calc_viewspace_z(zn, zf, sr[2]),
		fov = assert(viewfrustum.fov),
		aspect = assert(viewfrustum.aspect),
	}
end

function ishadow.split_viewfrustum(zn, zf, viewfrustum)
	local f = {}
	local ratios = ishadow.split_positions_to_ratios(ishadow.calc_split_positions(zn, zf))
	for _, r in ipairs(ratios) do
		f[#f+1] = create_sub_viewfrustum(zn, zf, r, viewfrustum)
	end

	return f
end

return ishadow

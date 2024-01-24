local setting	= import_package "ant.settings"

local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"
if not ENABLE_SHADOW then
	return
end

local mathpkg	= import_package "ant.math"
local mu		= mathpkg.util
local math3d	= require "math3d"

local bgfx		= require "bgfx"

local fbmgr		= require "framebuffer_mgr"
local sampler   = import_package "ant.render.core".sampler

local SHADOW_CFG = {
	normal_offset		= setting:get "graphic/shadow/normal_offset"	or 0.012,
	soft_shadow			= setting:get "graphic/shadow/soft_shadow",
	vsm					= {
		far_offset		= setting:get "graphic/shadow/vsm/far_offset"		or 0,
		depth_multiplier= setting:get "graphic/shadow/vsm/depth_multiplier" or 1000,
		min_variance	= setting:get "graphic/shadow/vsm/min_variance"		or 0.012,
	},
	pcf					= {
		fix4			= setting:get "graphic/shadow/pcf/fix4",
		kernelsize		= setting:get "graphic/shadow/pcf/kernelsize",
	},
	shadowmap_size		= setting:get "graphic/shadow/size",
	split_lamada		= setting:get "graphic/shadow/split_lamada",
	split_num			= setting:get "graphic/shadow/split_num",
	split_ratios		= setting:get "graphic/shadow/split_ratios",
}

bgfx.set_palette_color(0, 0.0, 0.0, 0.0, 0.0)

if SHADOW_CFG.split_ratios then
	if nil ~= SHADOW_CFG.split_num then
		if SHADOW_CFG.split_num ~= #SHADOW_CFG.split_ratios then
			error(("split_num:%d is not equal SHADOW_CFG.split_ratios number"):format(SHADOW_CFG.split_num, #SHADOW_CFG.split_ratios))
		end
	else
		SHADOW_CFG.split_num = #SHADOW_CFG.split_ratios
	end

	if #SHADOW_CFG.split_ratios > 4 then
		error(("max csm split num should lower than 4, %d is defined"):format(#SHADOW_CFG.split_ratios))
	end
else
	if nil == SHADOW_CFG.split_num then
		error "'split_ratios' or 'split_num' must be defined"
	end

	log.info("'split_ratios' is not define, use log split algrithom")
end

assert(SHADOW_CFG.split_num ~= nil)
SHADOW_CFG.split_frustums	= {nil, nil, nil, nil}

--check soft shadow
if SHADOW_CFG.soft_shadow == "vsm" then
	SHADOW_CFG.soft_shadow_param = math3d.ref(math3d.vector(SHADOW_CFG.depth_multiplier, SHADOW_CFG.min_variance, SHADOW_CFG.far_offset, 0.0))
elseif SHADOW_CFG.soft_shadow == "pcf" then
	if not SHADOW_CFG.pcf.fix4 then
		local k = SHADOW_CFG.pcf.kernelsize
		if 2.0 ~= k and 4.0 ~= k and 8.0 ~= k then
			error(("PCF kernel size should only be: 2.0/4.0/8.0, kernelsize: %2f is not valid"):format(k))
		end
		SHADOW_CFG.soft_shadow_param = math3d.ref(math3d.vector(k, 0.0, 0.0, 0.0))
	end
end

SHADOW_CFG.shadow_param1	= math3d.ref(math3d.vector(SHADOW_CFG.normal_offset, 1.0/SHADOW_CFG.shadowmap_size, SHADOW_CFG.split_num, 0.0))

SHADOW_CFG.fb_index = fbmgr.create(
	{
		rbidx=fbmgr.create_rb{
			format = "D32F",
			w=SHADOW_CFG.shadowmap_size * SHADOW_CFG.split_num,
			h=SHADOW_CFG.shadowmap_size,
			layers=1,
			flags=sampler{
				RT="RT_ON",
				--LINEAR for pcf2x2 with shadow2DProj in shader
				MIN="LINEAR",
				MAG="LINEAR",
				U="BORDER",
				V="BORDER",
				COMPARE="COMPARE_GEQUAL",
				BOARD_COLOR="0",
			},
		}
	}
)

local isc = {}

function isc.setting()
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

function isc.crop_matrix(csm_index)
	return crop_matrices[csm_index]
end

function isc.fb_index()
	return SHADOW_CFG.fb_index
end

function isc.shadow_param1()
	return SHADOW_CFG.shadow_param1
end

function isc.soft_shadow_param()
	return SHADOW_CFG.soft_shadow_param
end

function isc.split_frustums()
	return SHADOW_CFG.split_frustums
end

function isc.shadowmap_size()
	return SHADOW_CFG.shadowmap_size
end

function isc.split_num()
	return SHADOW_CFG.split_num
end

function isc.calc_uniform_split_positions()
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
function isc.calc_log_split_positions(near, far)
	local positions = {1.0}
	local sn = SHADOW_CFG.split_num
	for c=1, sn-1 do
		positions[#positions+1] = log_split(c, near, far)
	end
	return positions
end

function isc.calc_split_positions(near, far)
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

function isc.split_positions_to_ratios(positions)
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

function isc.split_viewfrustum(zn, zf, viewfrustum)
	local f = {}
	local ratios = SHADOW_CFG.split_ratios or isc.split_positions_to_ratios(isc.calc_split_positions(zn, zf))
	for _, r in ipairs(ratios) do
		f[#f+1] = create_sub_viewfrustum(zn, zf, r, viewfrustum)
	end

	return f
end

function isc.calc_focus_matrix(aabb)
	local center, extents = math3d.aabb_center_extents(aabb)

	local ex, ey = math3d.index(extents, 1, 2)
	local sx, sy = 1.0/ex, 1.0/ey

	local tx, ty = math3d.index(center, 1, 2)

	local quantizer = 16
	sx, sy = quantizer / math.ceil(quantizer / sx),  quantizer / math.ceil(quantizer / sy)

	tx, ty =  tx * sx, ty * sy
	local hs = isc.shadowmap_size() * 0.5
	tx, ty = -math.ceil(tx * hs) / hs, -math.ceil(ty * hs) / hs
	return math3d.matrix{
		sx,  0, 0, 0,
			0, sy, 0, 0,
			0,  0, 1, 0,
		tx, ty, 0, 1
	}
end

return isc

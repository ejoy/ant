local util = {}; util.__index = util

local mathpkg   = import_package "ant.math"
local ms        = mathpkg.stack

util.shadow_crop_matrix = ms:ref "matrix" {
	0.5, 0.0, 0.0, 0.0,
	0.0, -0.5, 0.0, 0.0,
	0.0, 0.0, 1.0, 0.0,
	0.5, 0.5, 0.0, 1.0,
}

function util.split_new_frustum_by_distance(view_frustum, n_dis, f_dis)
	assert(view_frustum.ortho == nil or view_frustum.ortho == false)
	local frustum = {}
	for k, v in pairs(view_frustum) do
		frustum[k] = v
	end

	assert(frustum.n <= n_dis and n_dis <= frustum.f)
	assert(frustum.n <= f_dis and f_dis <= frustum.f)

	frustum.n = n_dis
	frustum.f = f_dis
	assert(frustum.fov)
	return frustum
end

function util.split_new_frustum(view_frustum, ratios)
	assert(view_frustum.ortho == nil or view_frustum.ortho == false)

	local near_ratio, far_ratio = ratios[1], ratios[2]

	local z_len = view_frustum.f - view_frustum.n
	local n_dis = view_frustum.n + near_ratio * z_len
	local f_dis = view_frustum.n + far_ratio * z_len

	return util.split_new_frustum_by_distance(view_frustum, n_dis, f_dis)
end

function util.get_directional_light_dir(world)
	local d_light = world:first_entity "directional_light"
	return ms(d_light.rotation, "dP")
end

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

local split_distance_ratios = gen_ratios{0.18, 0.35, 0.65}

function util.calc_split_distance_ratio(min_ratio, max_ratio, near_clip, far_clip, lambda, num_splits)
	lambda = lambda and math.max(0, math.min(1, lambda)) or 1	-- clamp[0, 1]
	local clip_range = far_clip - near_clip

	local minZ = near_clip + min_ratio * clip_range;
	local maxZ = near_clip + max_ratio * clip_range;

	local z_range = maxZ - minZ;
	local ratio = maxZ / minZ;

	local distance_ratios = {}
	local pre_ratio = 0.0
	for i=1, num_splits do
		local p = i / num_splits
		local log = minZ * (ratio ^ p);
		local uniform = minZ + z_range * p;
		local d = lambda * (log - uniform) + uniform;
		local dis_ratio = (d - near_clip) / clip_range;
		distance_ratios[#distance_ratios+1] = {
			pre_ratio, dis_ratio,
		}
		pre_ratio = dis_ratio
	end

	return distance_ratios
end

function util.get_split_ratios()
	return split_distance_ratios
end

util.shadowmap_size = 1024

return util
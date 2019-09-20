local util = {}; util.__index = util

local mathpkg   = import_package "ant.math"
local ms        = mathpkg.stack

util.shadow_crop_matrix = ms:ref "matrix" {
	0.5, 0.0, 0.0, 0.0,
	0.0, -0.5, 0.0, 0.0,
	0.0, 0.0, 1.0, 0.0,
	0.5, 0.5, 0.0, 1.0,
}

function util.split_new_frustum(view_frustum, ratios)
	assert(view_frustum.ortho == nil or view_frustum.ortho == false)

	local near_ratio, far_ratio = ratios[1], ratios[2]
	local frustum = {}
	for k, v in pairs(view_frustum) do
		frustum[k] = v
	end

	local z_len = view_frustum.f - view_frustum.n
	frustum.n = view_frustum.n + near_ratio * z_len
	frustum.f = view_frustum.n + far_ratio * z_len

	assert(frustum.fov)
	return frustum
end

function util.get_directional_light_dir(world)
	local d_light = world:first_entity "directional_light"
	return ms(d_light.rotation, "dP")
end

return util
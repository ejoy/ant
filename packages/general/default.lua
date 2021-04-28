local default = {}; default.__index = default

local default_far_distance = 300
local default_near_distance = 1
function default.frustum(aspect)
	return {
		type = "mat",
		n = default_near_distance,
		f = default_far_distance,
		fov = 30,
		aspect = aspect or (4 / 3),
	}
end

function default.ortho_frustum(n, f, l, r, t, b)
	return {
		type = "mat",
		n = n or default_near_distance, f = f or default_far_distance,
		l = l or -1, r = r or 1,
		t = t or -1, b = b or 1,
		ortho = true,
	}
end

function default.render_buffer(w, h, format, flags)
	return {
		w = w,
		h = h,
		layers = 1,
		format = format,
		flags = flags,
	}
end

return default
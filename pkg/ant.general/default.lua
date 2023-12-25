local default = {}

local DEFAULT_NEAR<const>, DEFAULT_FAR<const> = 0.1, 1000
function default.frustum(aspect)
	return {
		n		= DEFAULT_NEAR,
		f		= DEFAULT_FAR,
		fov		= 60,
		aspect	= aspect or (4 / 3),
	}
end

function default.ortho_frustum(n, f, l, r, t, b)
	return {
		n = n or DEFAULT_NEAR, f = f or DEFAULT_FAR,
		l = l or -1, r = r or 1,
		t = t or -1, b = b or 1,
		ortho = true,
	}
end

function default.render_buffer(w, h, format, flags)
	return {
		w		= w,
		h		= h,
		layers	= 1,
		format	= format,
		flags	= flags,
	}
end

return default
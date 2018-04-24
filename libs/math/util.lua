local math3d = require "math3d"

local util = {}
util.__index = util

function util.limit(v, min, max)
    if v > max then return max end
    if v < min then return min end
    return v
end

function util.equal(n0, n1)
    assert(type(n0) == "number")
    assert(type(n1) == "number")
    return util.iszero(n1 - n0)
end

function util.iszero(n, threshold)
    threshold = threshold or 0.00001
    return -threshold <= n and n <= threshold
end

local function create_persistent_type(persistent_type, v)
	local t = math3d.ref(persistent_type)
	ms(t, v, "=")
	return t
end

local function to_v(ms, math_id)
	return ms(math_id, "m")
end

function util.srt(ms, s, r, t, ispersistent)
	local srt = {type="srt", s=s, r=r, t=t}
	if ispersistent then
		return create_persistent_type("matrix", srt)
	end

	return ms(srt, "P")
end

function util.srt_from_entity(ms, entity)
	return util.srt(ms, entity.scale.v, entity.rotation.v, entity.position.v)
end

function util.srt_v(ms, s, r, t, ispersistent)
	return to_v(ms, util.srt(ms, s, r, t, ispersistent))
end

function util.proj(ms, frustum, ispersistent)
	local t = {type = "proj", n=frustum.n, f=frustum.f, l=frustum.l, r=frustum.r, t=frustum.t, b=frustum.b}
	if frustum.isortho then
		t.type = "ortho"
	end

	if ispersistent then
		return create_persistent_type("matrix", t)
	end

	return ms(t, "P")
end

function util.proj_v(ms, frustum, ispersistent)
	return to_v(ms, util.proj(ms, frustum, ispersistent))
end

function util.degree_to_radian(angle)
	return (angle / 180) * math.pi
end

function util.radian_to_degree(radian)
	return (radian / math.pi) * 180
end

function util.frustum_from_fov(frustum, n, f, fov, aspect)
	local hh = math.tan(util.degree_to_radian(fov * 0.5)) * n
	local hw = aspect * hh
	frustum.n = n
	frustum.f = f
	frustum.l = -hw
	frustum.r = hw
	frustum.t = hh
	frustum.b = -hh
end

function util.create_persistent_vector(ms, value)
	local v = math3d.ref "vector"
	ms(v, value, "=")
	return v
end

function util.create_persistent_matrix(ms, value)
	local m = math3d.ref "matrix"
	ms(m, value, "=")
	return m
end

return util
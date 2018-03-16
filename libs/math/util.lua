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
	local t = {type="srt", s=s, r=s, t=t}
	if ispersistent then
		return create_persistent_type("matrix", t)
	end

	return ms(t, "P")
end

function util.srt_v(ms, s, r, t, ispersistent)
	return to_v(ms, util.srt(ms, s, r, t, ispersistent))
end

function util.srt_from_entity(ms, entity)
	return util.srt_v(ms, entity.scale.v, entity.direction.v, entity.position.v)
end

function util.proj(ms, frustum, ispersistent)
	local t = {type = "proj", fov=frustum.fov, aspect = frustum.aspect, n=frustum.near, f=frustum.far}
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

-- function util.lookat(ms, eye, dir, ispersistent)
-- 	if ispersistent then
-- 		local v = math3d
-- 	end

-- 	return ms(eye, dir, )
-- end

-- function util.lookat_v(ms, eye, dir)

-- end

return util
local util = {}
util.__index = util

local math3d = require "math3d"

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

function util.print_srt(e, numtab)
	local tab = ""
	if numtab then
		for i=1, numtab do
			tab = tab .. '\t'
		end
	end
	
	local srt = e.transform
	local s_str = tostring(srt.s)
	local r_str = tostring(srt.r)
	local t_str = tostring(srt.t)

	print(tab .. "scale : ", s_str)
	print(tab .. "rotation : ", r_str)
	print(tab .. "position : ", t_str)
end

function util.srt(s, r, t)
	return {
		s = s or {1, 1, 1, 0},
		r = r or {0, 0, 0, 1},
		t = t or {0, 0, 0, 1},
	}
end

function util.scale_mat(s)
	local stype = type(s)
	if type(s) == "number" then
		return util.srt {s, s, s, 0}
	end
	assert(stype == "table")
	return util.srt(s)
end

function util.rotation_mat(r)
	return util.srt(nil, r)
end

function util.translate_mat(t)
	return util.srt(nil, nil, t)
end

function util.ratio(start, to, t)
	return (t - start) / (to - start)
end

local function list_op(l, op)
	local t = {}
	for _, v in ipairs(l) do
		t[#t+1] = op(v)
	end
	return t
end

function util.view_proj(camera, frustum)
	local viewmat = math3d.lookto(camera.eyepos, camera.viewdir, camera.updir)
	frustum = frustum or camera.frustum
	local projmat = math3d.projmat(frustum)
	return math3d.mul(projmat, viewmat)
end

function util.to_radian(angles) return list_op(angles, math.rad) end
function util.to_angle(radians) return list_op(radians, math.deg) end

return util

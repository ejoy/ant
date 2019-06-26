local ms = require "stack"

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

function util.view_proj_matrix(e)
	local camera = assert(e.camera)
	local vr = e.view_rect
	local frustum = camera.frustum
	frustum.aspect = vr.w / vr.h
	return ms:view_proj(camera, camera.frustum)
end

function util.srt(s, r, t)
	return {
		s = s or {1, 1, 1, 0},
		r = r or {0, 0, 0, 0},
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

function util.identity_transform()
	return util.srt()
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

function util.to_radian(angles) return list_op(angles, math.rad) end
function util.to_angle(radians) return list_op(radians, math.deg) end

function util.AXIS(name)
	if name == "X" then
		return {1, 0, 0, 0}
	end

	if name == "Y" then
		return {0, 1, 0, 0}
	end

	if name == "Z" then
		return {0, 0, 1, 0}
	end
end

util.XAXIS = ms:ref "vector" {1, 0, 0, 0}
util.NXAXIS = ms:ref "vector" {-1, 0, 0, 0}
util.YAXIS = ms:ref "vector" {0, 1, 0, 0}
util.NYAXIS = ms:ref "vector" {0, -1, 0, 0}
util.ZAXIS = ms:ref "vector" {0, 0, 1, 0}
util.NZAXIS = ms:ref "vector" {0, 0, -1, 0}

return util

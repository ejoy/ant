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

function util.identity_transform()
	return {
		s = {1, 1, 1, 0},
		r = {0, 0, 0, 0},
		t = {0, 0, 0, 1},
	}
end

util.XAXIS = ms:ref "vector" {1, 0, 0, 0}
util.NXAXIS = ms:ref "vector" {-1, 0, 0, 0}
util.YAXIS = ms:ref "vector" {0, 1, 0, 0}
util.NYAXIS = ms:ref "vector" {0, -1, 0, 0}
util.ZAXIS = ms:ref "vector" {0, 0, 1, 0}
util.NZAXIS = ms:ref "vector" {0, 0, -1, 0}

return util

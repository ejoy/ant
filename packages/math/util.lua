local util = {}
util.__index = util

local math3d = require "math3d"
local constant = require "constant"

function util.limit(v, min, max)
    if v > max then return max end
    if v < min then return min end
    return v
end

function util.iszero(n, threshold)
    threshold = threshold or 0.00001
    return -threshold <= n and n <= threshold
end

function util.equal(n0, n1, threshold)
    assert(type(n0) == "number")
    assert(type(n1) == "number")
    return util.iszero(n1 - n0, threshold)
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

function util.lerp(v1, v2, t)
	return v1 * (1-t) + v2 * t
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

function util.pt2D_to_NDC(pt2d, rt)
	local x, y = rt.x or 0, rt.y or 0
	local vp_pt2d = {pt2d[1]-x, pt2d[2]-y}
    local screen_y = vp_pt2d[2] / rt.h
	if not math3d.get_origin_bottom_left() then
        screen_y = 1 - screen_y
    end

    return {
        (vp_pt2d[1] / rt.w) * 2 - 1,
        (screen_y) * 2 - 1,
    }
end

function util.NDC_near_pt(ndc2d)
	return {
		ndc2d[1], ndc2d[2], (math3d.get_homogeneous_depth() and -1 or 0)
	}
end

function util.NDC_near_far_pt(ndc2d)
	return util.NDC_near_pt(ndc2d), {
		ndc2d[1], ndc2d[2], 1
	}
end

function util.world_to_screen(vpmat, vr, posWS)
	--local vp = icamera.calc_viewproj(camera_ref)
	local posNDC = math3d.transformH(vpmat, posWS, 1)
	local screenNDC = math3d.muladd(posNDC, 0.5, 0.5)
	local sy = math3d.index(screenNDC, 2)
	if not math3d.get_origin_bottom_left() then
		screenNDC = math3d.set_index(screenNDC, 2, 1.0 - sy)
	end
	return math3d.mul(screenNDC, math3d.vector(vr.w, vr.h, 1.0))
end

function util.ndc_to_world(vpmat, ndc)
    local invviewproj = math3d.inverse(vpmat)
	return math3d.transformH(invviewproj, ndc, 1)
end

function util.pt_line_distance(p1, p2, p)
	local d = math3d.normalize(math3d.sub(p2, p1))
	local x = math3d.cross(constant.YAXIS, d)
	if util.iszero(math3d.dot(x, x)) then
		x = math3d.cross(constant.XAXIS, d)
	end
	local n = math3d.cross(d, x)
	
	return math3d.dot(p1, n) - math3d.dot(p, n)
end

--p1, p2 must be 0.0
function util.pt2d_line_distance(p1, p2, p)
	local d = math3d.normalize(math3d.sub(p2, p1))
    local x, y, z = math3d.index(d, 1, 2, 3)
	assert(z == 0, "we assume pt2d is 3d vector where z component is 0.0")
    local n = math3d.vector(y, -x, 0.0)
    return math3d.dot(p1, n) - math3d.dot(p, n)
end

function util.to_radian(angles) return list_op(angles, math.rad) end
function util.to_angle(radians) return list_op(radians, math.deg) end


function util.random(r)
	local t = math.random()
	return util.lerp(r[1], r[2], t)
end

function util.min(a, b)
	local t = {}
	for i=1, 3 do
		t[i] = math.min(a[i], b[i])
	end
	return t
end

function util.max(a, b)
	local t = {}
	for i=1, 3 do
		t[i] = math.max(a[i], b[i])
	end
	return t
end

function util.srt_obj(srt)
	if srt == nil then
		return {
			s = math3d.ref(constant.ONE),
			r = math3d.ref(constant.IDENTITY_QUAT),
			t = math3d.ref(constant.ZERO_PT),
		}
	end
	local s = srt.s
	if type(s) == "number" then
		s = {s, s, s}
	end
	return {
		s = math3d.ref(srt.s and math3d.vector(s) or constant.ONE),
		r = math3d.ref(srt.r and math3d.quaternion(srt.r) or constant.IDENTITY_QUAT),
		t = math3d.ref(srt.t and math3d.vector(srt.t) or constant.ZERO_PT),
	}
end

return util


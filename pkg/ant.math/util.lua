return function (math3d, constant)

local util = {}

local function bounce_time(time)
    if time < 1 / 2.75 then
        return 7.5625 * time * time
    elseif time < 2 / 2.75 then
        time = time - 1.5 / 2.75
        return 7.5625 * time * time + 0.75

    elseif time < 2.5 / 2.75 then
        time = time - 2.25 / 2.75
        return 7.5625 * time * time + 0.9375
    end
    time = time - 2.625 / 2.75
    return 7.5625 * time * time + 0.984375
end

util.TWEEN_LINEAR = 1
util.TWEEN_CUBIC_IN = 2
util.TWEEN_CUBIC_OUT = 3
util.TWEEN_CUBIC_INOUT = 4
util.TWEEN_BOUNCE_IN = 5
util.TWEEN_BOUNCE_OUT = 6
util.TWEEN_BOUNCE_INOUT = 7
util.tween = {
    function (time) return time end,
    function (time) return time * time * time end,
    function (time)
        time = time - 1
        return (time * time * time + 1)
    end,
    function (time)
        time = time * 2
        if time < 1 then
            return 0.5 * time * time * time
        end
        time = time - 2;
        return 0.5 * (time * time * time + 2)
    end,
    function (time) return 1 - bounce_time(1 - time) end,
    function (time) return bounce_time(time) end,
    function (time)
        local newT = 0
        if time < 0.5 then
            time = time * 2;
            newT = (1 - bounce_time(1 - time)) * 0.5
        else
            newT = bounce_time(time * 2 - 1) * 0.5 + 0.5
        end
        return newT
    end,
}

function util.limit(v, min, max)
    if v > max then return max end
    if v < min then return min end
    return v
end

local ZERO_THRESHOLD<const> = 10e-6

function util.iszero_math3dvec(v, threshold)
	return math3d.isequal(v, constant.ZERO, threshold)
end

function util.iszero(n, threshold)
    threshold = threshold or ZERO_THRESHOLD
    return math.abs(n) <= threshold
end

function util.equal(n0, n1, threshold)
    assert(type(n0) == "number")
    assert(type(n1) == "number")
    return util.iszero(n1 - n0, threshold)
end

function util.equal3d(v0, v1, threshold)
	local v = math3d.sub(v0, v1)
	local sq_len = math3d.dot(v, v)
	return util.iszero(sq_len, threshold)
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
	local posNDC = math3d.transformH(vpmat, posWS, 1)
	local screenNDC = math3d.muladd(posNDC, 0.5, math3d.vector(0.5, 0.5, 0.0))
	local sy = math3d.index(screenNDC, 2)
	if not math3d.get_origin_bottom_left() then
		screenNDC = math3d.set_index(screenNDC, 2, 1.0 - sy)
	end
	local r = math3d.mul(screenNDC, math3d.vector(vr.w, vr.h, 1.0))

	local ratio = vr.ratio
	if ratio ~= nil and ratio ~= 1 then
		local z = math3d.index(r, 3)
		local sr = math3d.mul(1.0 / ratio, r)
		return math3d.set_index(sr, 3, z)
	end
	return r
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

local function pt2d_line(p1, p2, p)
	local d = math3d.normalize(math3d.sub(p2, p1))
    local x, y, z = math3d.index(d, 1, 2, 3)
	--assert(z == 0, "we assume pt2d is 3d vector where z component is 0.0")
    local n = math3d.vector(y, -x, 0.0)
    return math3d.dot(p1, n) - math3d.dot(p, n), n
end

--p1, p2 must be 0.0
function util.pt2d_line_distance(p1, p2, p)
	return pt2d_line(p1, p2, p)
end

function util.pt2d_line_intersect(p1, p2, p)
	local d, n = pt2d_line(p1, p2, p)
	return d, math3d.muladd(d, n, p)
end

function util.pt2d_in_line(p1, p2, p)
	local pp1 = math3d.sub(p1, p)
	local pp2 = math3d.sub(p2, p)
	local r = math3d.dot(pp1, pp2)
	return r <= 0
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

function util.pt2d_in_rect(x, y, rt)
	return rt.x <= x and rt.y <= y and x <=(rt.x+rt.w) and y <=(rt.y+rt.h)
end

function util.is_rect_equal(lhs, rhs)
	return	lhs.x == rhs.x and lhs.y == rhs.y and
			lhs.w == rhs.w and lhs.h == rhs.h
end

function util.cvt_size(s, ratio, dv)
	dv = dv or 1
	return math.max(dv, math.floor(s*ratio))
end

function util.calc_viewrect(vr, ratio)
	if ratio == 1 then
		return vr
	end
	return {
		x = vr.x and util.cvt_size(vr.x, ratio, 0) or nil,
		y = vr.y and util.cvt_size(vr.y, ratio, 0) or nil,
		w = util.cvt_size(vr.w, ratio),
		h = util.cvt_size(vr.h, ratio),
	}
end

function util.get_scene_view_rect(resolution, device, scene_ratio)
	-- todo : unused scene_ratio
	local resolution_ratio = resolution.w / resolution.h
	local device_ration = device.w / device.h
	local scale
	if device_ration > resolution_ratio then
		-- long
		if device.h > resolution.h then
			scale = resolution.h / device.h
		end
	else
		if device.w > resolution.w then
			scale = resolution.w / device.w
		end
	end
	if scale then
		return { x = 0, y = 0, w = math.floor(device.w * scale + 0.5), h = math.floor(device.h * scale + 0.5) }
	else
		return { x = 0, y = 0, w = device.w , h =device.h }
	end
end

function util.get_fix_ratio_scene_viewrect(vp, aspect_ratio, scene_ratio)
	return {scene_ratio = scene_ratio, h = math.floor(vp.h), w = math.floor(aspect_ratio*vp.h), x = vp.x, y = vp.y}
end

function util.remap_xy(x, y, ratio)
	if ratio ~= nil and ratio ~= 1 then
        x, y = util.cvt_size(x, ratio), util.cvt_size(y, ratio)
    end
    return x, y
end

function util.texture_uv(rect, size)
	return {rect.x/size.w, rect.y/size.h, (rect.x+rect.w)/size.w, (rect.y+rect.h)/size.h}
end

function util.copy_viewrect(vp)
	return {x=vp.x, y=vp.y, w=vp.w, h=vp.h, ratio=vp.ratio}
end

function util.copy2viewrect(srcvr, dstvr)
	dstvr.x, dstvr.y, dstvr.w, dstvr.h = srcvr.x, srcvr.y, srcvr.w, srcvr.h
	dstvr.ratio = srcvr.ratio
end

local function remap_NO(x)
	return x * 2.0 - 1.0
end

function util.rect2ndc(rect, viewrect)
	local nx, ny = rect.x/viewrect.w, rect.y/viewrect.h
	local nw, nh = rect.w/viewrect.w, rect.h/viewrect.h
	ny = 1.0 - ny
	nx, ny = remap_NO(nx), remap_NO(ny)

	local ww, hh = 2*nw, 2*nh
	return {x=nx, y=ny-hh, w=ww, h=hh,}	--ny-hh: to move (x, y) to bottom left
end

function util.rectpoints(rect)
	local x, y, w, h = rect.x, rect.y, rect.w, rect.h
	return {
		x, 		y,
		x,		y + h,
		x + w, 	y,
		x + w, 	y + h,
	}
end

local function isnan(v, ...)
	if v then
		if v ~= v then
			return true
		end

		return util.isnan(...)
	end
end

util.isnan = isnan

function util.isnan_math3dvec(v)
	return isnan(math3d.index(v, 1, 2, 3, 4))
end

do
	-- topleft origin and homogeneous depth matrix
	local m = {
		0.5, 0.0, 0.0, 0.0,
		0.0, -0.5, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		0.5, 0.5, 0.0, 1.0,
	}

	if math3d.get_origin_bottom_left() then
		m[6] = -m[6]
	end

	if math3d.get_homogeneous_depth() then
		m[11], m[15] = 0.5, 0.5
	end

	util.texture_bias_matrix = math3d.ref(math3d.matrix(m))
end

function util.create_ray(s0, s1)
	return {o=s0, d=math3d.sub(s1, s0)}
end

function util.ray_point(ray, t)
	return math3d.muladd(ray.d, t, ray.o)
end

function util.ray_triangle(ray, v0, v1, v2)
	local success, t = math3d.triangle_ray(ray.o, ray.d, v0, v1, v2)
	if success then
		return util.ray_point(ray, t)
	end
end

function util.segment_triangle(s0, s1, v0, v1, v2)
	local r = util.create_ray(s0, s1)
	local success, t = math3d.triangle_ray(r.o, r.d, v0, v1, v2)
	if success and 0 <= t and t <= 1.0 then
		return util.ray_point(r, t)
	end
end

--polar coordinate
function util.polar2xyz(theta, phi, r)
	if r then
		return r * math.cos(theta) * math.sin(phi), r * math.sin(theta) * math.sin(phi), r * math.cos(theta)
	else
		return math.cos(theta) * math.sin(phi), math.sin(theta) * math.sin(phi), math.cos(theta)
	end
end

function util.xyz2polar(x, y, z, need_normalize)
	if need_normalize then
		local l = math.sqrt(x*x+y*y+z*z)
		if util.iszero(l) then
			return 0, 0
		end
		x, y, z = x/l, y/l, z/l
		return math.acos(z), math.asin(x/z)
	end

	--x = math.cos(theta) * math.sin(phi)
	--x/math.cos(theta) = math.sin(phi)
	return math.acos(z), math.asin(x/z), 1
end

local function quat_inverse_sign(q)
	local qx, qy, qz, qw = math3d.index(q, 1, 2, 3, 4)
	return math3d.quaternion(-qx, -qy, -qz, -qw)
end

function util.unpack_tangent_frame(q)
	local x, y, z, w = math3d.index(q, 1, 2, 3, 4)
	local zwx = math3d.vector(z, w, x, 0.0)
	local wzy = math3d.vector(w, z, y, 0.0)
	local yxw = math3d.vector(y, x, w, 0.0)
	local function quat_to_normal()
		return	math3d.add(
					math3d.vector(0.0, 0.0, 1.0 ),
				math3d.muladd(	math3d.mul(math3d.vector(2.0,-2.0,-2.0 ), x), zwx,
								math3d.mul(math3d.mul(math3d.vector(2.0, 2.0,-2.0 ), y), wzy)))
	end

	local function quat_to_tangent()
		return
			math3d.add(math3d.vector( 1.0, 0.0, 0.0 ),
				math3d.muladd(math3d.mul(math3d.vector(-2.0, 2.0,-2.0 ), y), yxw,
				math3d.mul(math3d.mul(math3d.vector(-2.0, 2.0, 2.0 ), z), zwx))
			)
	end

	return quat_to_normal(), quat_to_tangent()
end

--normal: normalize
--tangent: [tx, ty, tz, tw], it must have 4 elements, and tw element must be 1.0 or -1.0, where -1.0 indicate reflection is existd
--storage_size: default is 2
function util.pack_tangent_frame(normal, tangent, storage_size)
	storage_size = storage_size or 2
	local q = math3d.normalize(
			math3d.quaternion(
				math3d.matrix(tangent, math3d.cross(normal, tangent), normal, constant.ZERO_PT)
			))

	local qw = math3d.index(q, 4)

	-- make sure qw is positive, because we need sign of this quaternion to tell shader is the tangent frame is invert or not
	if qw < 0 then
		q = quat_inverse_sign(q)
		qw = -qw	--math3d.index(q, 4)
	end

	-- Ensure w is never 0.0
    -- Bias is 2^(nb_bits - 1) - 1
	local CHAR_BIT<const> = 8
	local bias = 1.0 / ((1 << (storage_size * CHAR_BIT - 1)) - 1)
	if qw < bias then
		qw = bias

		local factor = math.sqrt(1.0 - bias * bias)
		local qx, qy, qz = math3d.index(q, 1, 2, 3)
		q = math3d.quaternion(qx*factor, qy*factor, qz*factor, qw)
	end
	local tw = math3d.index(tangent, 4)
	if tw < 0 then
		q = quat_inverse_sign(q)
	end
	return q
end

function util.from_mat3(
    c11, c12, c13,
    c21, c22, c23,
    c31, c32, c33)
    return {
        c11, c12, c13, 0.0,
        c21, c22, c23, 0.0,
        c31, c32, c33, 0.0,
        0.0, 0.0, 0.0, 0.0}
end

function util.from_cmat3(...)
    return math3d.constant("mat", util.from_mat3(...))
end

function util.check_nan(v)
    return v ~= v and 0 or v
end

local HALF_UINT16<const> = 32767
function util.h2f(h)
	return h/HALF_UINT16
end

function util.f2h(f)
	return math.floor(util.check_nan(f)*HALF_UINT16 + 0.5)
end

function util.H2B(H)
	return math.floor(H/65535.0*255+0.5)
end

function util.clamp_vec(v, minv, maxv)
	return math3d.max(minv, math3d.min(v, maxv))
end

function util.saturate_vec(v)
	return util.clamp_vec(v, constant.ZERO, constant.ONE_PT)
end

function util.clamp(v, minv, maxv)
    return math.min(maxv, math.max(minv, v))
end

function util.smoothstep(e0, e1, v)
    local t = util.clamp((v - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
end

function util.saturate(v)
	return util.clamp(v, 0.0, 1.0)
end

function util.aabb_minmax(aabb)
	return math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
end

function util.aabb_minmax_index(aabb, idx)
	local minv, maxv = util.aabb_minmax(aabb)
	return math3d.index(minv, idx), math3d.index(maxv, idx)
end


function util.iter_m3darary(m3darray)
	local n = math3d.array_size(m3darray)
	return function (_, idx)
		idx = idx + 1
		if idx <= n then
			return idx, math3d.array_index(m3darray, idx)
		end
	end, m3darray, 0
end

function util.M3D_mark(old, new)
	if old then
		math3d.unmark(old)
	end
	return math3d.mark(new)
end

return util

end

local math3d = require "math3d"

do
	print "---- constant -------"
	local c = math3d.constant "null"
	print(c, math3d.mark(c))
	print(math3d.tostring(c))
	local c = math3d.constant "v4"
	print(math3d.tostring(c))
	local c = math3d.constant "quat"
	print(math3d.tostring(c))
	local c = math3d.constant "mat"
	print(math3d.tostring(c))

	local iv = math3d.constant { type = "v4" }
	print(math3d.tostring(iv))
	local qv = math3d.constant { type = "quat" }
	print(math3d.tostring(qv))
	local mv = math3d.constant { type = "mat" }
	print(math3d.tostring(mv))

	local vec = math3d.constant { type = "v4", 1,2,3,4 }
	print(math3d.tostring(vec))

	local vec = math3d.constant ("v4", { 0,0,0,0 })
	print(math3d.tostring(vec))
end

local ref1, ref2, ref3

do
	print "----- ref ------"

	ref1 = math3d.ref()

	ref1.m = { s = 10, r = { axis = {1,0,0}, r = math.rad(60) },  t = { 1,2,3 } }

	ref2 = math3d.ref()

	ref2.v = math3d.vector(1,2,3,4)

	print("ref1", ref1)
	print("ref1 value", math3d.tostring(math3d.matrix(ref1)))
	print(ref2)
	print("ref2 value", math3d.tostring(math3d.vector(ref2)))
	ref2.v = math3d.pack("dddd", 1,2,3,4)
	print(ref2)
	ref2.v = math3d.vector(ref2, 1)
	print("ref2", ref2)
end

print "-----plane test-----"
do
	--[[
		    local d1dotn = math3d.dot(plane, ray.d)
			local t = 0.0
			if math.abs(d1dotn) > 1e-7 then
				local dis = math3d.index(plane, 4)
				local odotn = math3d.dot(ray.o, plane)
				t = (dis - odotn) / d1dotn
			end
			local intersetion_pt = math3d.muladd(ray.d, tt, ray.o)
	]]
	local plane_pos = math3d.vector(0, 3, 0)
	local plane_dir = math3d.vector(0, 10, 0)
	local plane = math3d.plane(plane_pos, plane_dir)

	local ray = {o = math3d.vector(0, 10, 0), d = math3d.vector(0.0, -3, 0.0)}
	local tt = math3d.plane_ray(ray.o, ray.d, plane)
	if tt == 0 then
		print "plane parallel with ray"
	elseif tt < 0 then
		print "plane intersetion in ray backward"
	else
		print "plane intersetion with plane front face"
	end

	local intersetion_pt = math3d.muladd(ray.d, tt, ray.o)
	print(math3d.tostring(intersetion_pt))
end

print "===SRT==="
do
	ref1.m = { r = { 0, math.rad(60), 0 }, t = { 1,2,3} }	-- .s = 1
	print(ref1)
	local s,r,t = math3d.srt(ref1)
	print("S = ", math3d.tostring(s))
	print("R = ", math3d.tostring(r))
	print("T = ", math3d.tostring(t))

	local function print_srt()
		print("S = ", math3d.tostring(ref1.s))
		print("R = ", math3d.tostring(ref1.r))
		print("T = ", math3d.tostring(ref1.t))
	end

	print_srt()
end

print "===QUAT==="
do
	local q = math3d.quaternion { 0, math.rad(60, 0), 0 }
	print(math3d.tostring(q))
	ref3 = math3d.ref()
	ref3.m = math3d.quaternion { axis = {1,0,0}, r = math.rad(60) } -- init mat with quat
	print(ref3)
	ref3.q = ref3	-- convert mat to quat
	print(ref3)

	print(math3d.tostring(math3d.constant "quat", math3d.constant "quat"))	-- Identity quat
end

print "===FUNC==="
do
	ref2.v = math3d.vector(1,2,3,4)
	print(ref2)
	ref2.v = math3d.add(ref2,ref2,ref2)
	print(ref2)
	ref2.v = math3d.mul(ref2, 2.5)
	print("length", ref2, "=", math3d.length(ref2))
	print("floor", ref2, "=", math3d.tostring(math3d.floor(ref2)))
	print("dot", ref2, ref2, "=", math3d.dot(ref2, ref2))
	print("cross", ref2, ref2, "=", math3d.tostring(math3d.cross(ref2, ref2)))
	print("normalize", ref2, "=", math3d.tostring(math3d.normalize(ref2)))
	print("normalize", ref3, "=", math3d.tostring(math3d.normalize(ref3)))
	print("transpose", ref1, "=", math3d.tostring(math3d.transpose(ref1)))
	local point = math3d.vector(1, 2, 3, 1)
	print("transformH", ref1, point, "=", math3d.tostring(math3d.transformH(ref1, point)))
	print("inverse", ref1, "=", math3d.tostring(math3d.inverse(ref1)))
	print("inverse", ref2, "=", math3d.tostring(math3d.inverse(ref2)))
	print("inverse", ref3, "=", math3d.tostring(math3d.inverse(ref3)))
	print("reciprocal", ref2, "=", math3d.tostring(math3d.reciprocal(ref2)))
end

print "===INVERSE==="
do
	local m = math3d.lookto(math3d.vector(1, 2, 1), math3d.vector(1, -1, 1))
	local imf = math3d.inverse_fast(m)
	local mf = math3d.inverse(m)

	print("look to matrix:", math3d.tostring(m))
	print("inverse fast:", math3d.tostring(imf))
	print("inverse:", math3d.tostring(mf))
end

print "===MULADD==="
do
	local v1, v2 = math3d.vector(1, 2, 3, 0), math3d.vector(1, 0, 0, 0)
	local p = math3d.vector(4, 1, 0, 1)
	local r = math3d.muladd(v1, v2, p)
	print("muladd:", math3d.tostring(v1), math3d.tostring(v2), math3d.tostring(p), "=", math3d.tostring(r))
end

print "===VIEW&PROJECTION MATRIX==="
do
	local eyepos = math3d.vector( 0, 5, -10 )
	local at = math3d.vector (0, 0, 0)
	local direction = math3d.normalize(math3d.vector (1, 1, 1))
	local updir = math3d.vector (0, 1, 0)

	local mat1 = math3d.lookat(eyepos, at, updir)
	local mat2 = math3d.lookto(eyepos, direction, updir)

	print("lookat matrix:", math3d.tostring(mat1), "eyepos:", math3d.tostring(eyepos), "at:", math3d.tostring(at))

	print("lookto matrix:", math3d.tostring(mat2), "eyepos:", math3d.tostring(eyepos), "direction:", math3d.tostring(direction))

	local frustum = {
		l=-1, r=1,
		t=-1, b=1,
		n=0.1, f=100
	}

	local perspective_mat = math3d.projmat(frustum)

	local frustum_ortho = {
		l=-1, r=1,
		t=-1, b=1,
		n=0.1, f=100,
		ortho = true,
	}
	local ortho_mat = math3d.projmat(frustum_ortho)

	print("perspective matrix:", math3d.tostring(perspective_mat))
	print("ortho matrix:", math3d.tostring(ortho_mat))
end

print "===ROTATE VECTOR==="
do
	local v = math3d.vector{1, 2, 1}
	local q = math3d.quaternion {axis=math3d.vector{0, 1, 0}, r=math.pi * 0.5}
	local vv = math3d.transform(q, v, 0)
	print("rotate vector with quaternion", math3d.tostring(v), "=", math3d.tostring(vv))

	local mat = math3d.matrix {s=1, r=q, t=math3d.vector{0, 0, 0, 1}}
	local vv2 = math3d.transform(mat, v, 0)
	print("transform vector with matrix", math3d.tostring(v), "=", math3d.tostring(vv2))

	local p = math3d.vector{1, 2, 1, 1}
	local mat2 = math3d.matrix {s=1, r=q, t=math3d.vector{0, 0, 5, 1}}
	local r_p = math3d.transform(mat2, p, nil)
	print("transform point with matrix", math3d.tostring(p), "=", math3d.tostring(r_p))
end

print "===construct coordinate from forward vector==="
do
	local forward = math3d.normalize(math3d.vector {1, 1, 1})
	local right, up = math3d.base_axes(forward)
	print("forward:", math3d.tostring(forward), "right:", math3d.tostring(right), "up:", math3d.tostring(up))
end

print "===PROJ===="
do
	local projmat = math3d.projmat {fov=90, aspect=1, n=1, f=1000}
	print("PROJ", math3d.tostring(projmat))
end

print "===ADAPTER==="
local adapter = require "math3d.adapter"
local testfunc = require "math3d.adapter.test"

local vector = adapter.vector(testfunc.vector, 1)	-- convert arguments to vector pointer from 1
local matrix1 = adapter.matrix(testfunc.matrix1, 1, 1)	-- convert 1 mat
local matrix2 = adapter.matrix(testfunc.matrix2, 1, 2)	-- convert 2 mat
local matrix = adapter.matrix(testfunc.matrix2, 1)	-- convert all mat
local var = adapter.variant(testfunc.vector, testfunc.matrix1, 1)
local format = adapter.format(testfunc.variant, testfunc.format, 2)
local mvq = adapter.getter(testfunc.getmvq, "mvq")	-- getmvq will return matrix, vector, quat
local matrix2_v = adapter.format(testfunc.matrix2, "mm", 1)
local retvec = adapter.output_vector(testfunc.retvec, 1)
print(vector(ref2, math3d.vector{1,2,3}))
print(matrix1(ref1))
print(matrix2(ref1,ref1))
print(matrix2_v(ref1,ref1))
print(matrix(ref1,ref1))
print(var(ref1))
print(var(ref2))
print(format("mv", ref1, ref2))
local m,v, q = mvq()
print(math3d.tostring(m), math3d.tostring(v), math3d.tostring(q))

local v1,v2 =retvec()
print(math3d.tostring(v1), math3d.tostring(v2))


print "===AABB&FRUSTUM==="
do
	local aabb = math3d.ref(math3d.aabb(math3d.vector(-1, 2, 3), math3d.vector(1, 2, -3), math3d.vector(-2, 3, 6)))
	assert(math3d.array_size(aabb) == 2)
	print("aabb:min", math3d.tostring(math3d.array_index(aabb,0)), "aabb:max", math3d.tostring(math3d.array_index(aabb,1)))

	local transformmat = math3d.matrix(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 3, 1)
	aabb = math3d.aabb_transform(transformmat, aabb)

	local vp = math3d.mul(math3d.projmat{aspect=60, fov=1024/768, n=0.1, f=100}, math3d.lookto(math3d.vector(0, 0, -10), math3d.vector(0, 0, 1)))
	local frustum_planes = math3d.frustum_planes(vp)
	local frustum_points = math3d.frustum_points(vp)

	local intersectresult = math3d.frustum_intersect_aabb(frustum_planes, aabb)

	print("aabb:", math3d.tostring(aabb))

	local frustum_point_names = {
		"lbn", "rbn", "ltn", "rtn",
		"lbf", "rbf", "ltf", "rtf",
	}
	local frustuminfo={}
	for i=1, 8 do
		frustuminfo[#frustuminfo+1] = frustum_point_names[i] .. ":" .. math3d.tostring(frustum_points[i])
	end
	print("frustum:\n", table.concat(frustuminfo, ",\n\t"))

	if intersectresult > 0 then
		print("aabb inside frustum")
	elseif intersectresult == 0 then
		print("aabb intersect with frustum")
	else
		print("aabb outside frustum")
	end

	local center = math3d.points_center(frustum_points)
	local maxradius = math3d.points_radius(frustum_points, center)
--[[
	local frustum_aabb = math3d.frustum_aabb(frustum_points)

	print("frusutm center:", math3d.tostring(center))
	print("frustum max radius:", maxradius)

	local f_aabb_min, f_aabb_max = math3d.index(frustum_aabb, 1), math3d.index(frustum_aabb, 2)
	print("frusutm aabb min:", math3d.tostring(f_aabb_min), "max:", math3d.tostring(f_aabb_max))
	local f_aabb_center, f_aabb_extents = math3d.aabb_center_extents(frustum_aabb)
	print("frusutm aabb center:", math3d.tostring(f_aabb_center), "extents:", math3d.tostring(f_aabb_extents), "radius:", math3d.length(f_aabb_extents))
]]
	print "\t===AABB&minmax===="
	local points = {
		{1, 0, -1, -10},
		{1, 2, -1, 1},
		{1, 4, -5, 1},
		{-2, 0, -1, 1},
	}

	local min, max = math3d.minmax(points)
	local aabb = math3d.aabb(min, max)
	local aabb2 = math3d.aabb()
	aabb2 = math3d.aabb_append(aabb2, table.unpack(points))

	print("minmax-aabb:", math3d.tostring(aabb))
	print("aabb-append:", math3d.tostring(aabb2))
end

local r2l_mat = math3d.matrix{s={-1.0, 1.0, 1.0}}
local r2l_mat1 = math3d.matrix{s={1.0, 1.0, -1.0}}
local r2l_mat2 = math3d.matrix{s={-1.0, -1.0, -1.0}}

local function print_mat(mat)
	print "origin matrix:"
	print(math3d.tostring(mat))
	local p = math3d.vector(1, 2, 3, 1)

	print "transform point:(1, 2, 3, 1)"
	print(math3d.tostring(math3d.transform(mat, p, 1)))
	local s, r, t = math3d.srt(mat)

	print("srt.s:", math3d.tostring(s))
	print("srt.r:", math3d.tostring(r))
	print("srt.t:", math3d.tostring(t))

	print "transform srt.s by srt.r"
	print(math3d.tostring(math3d.transform(r, s, 0)))

	local m = math3d.matrix{s=s, r=r, t=t}
	print "combine matrix:"
	print(math3d.tostring(m))
	print "transform point:(1, 2, 3, 1) by combine matrix"
	print(math3d.tostring(math3d.transform(m, p, 1)))
end
print "test matrix decompose to s, r, t"
print_mat(r2l_mat)
print_mat(r2l_mat1)
print_mat(r2l_mat2)

do
	print "Inverse Z projection matrix:"
	local frustum = {
		l = -1.0, r = 1.0, t = 1.0, b = -1.0,
		n = 1.0, f = 100
	}
	local invz_proj = math3d.projmat(frustum, true)
	local proj = math3d.projmat(frustum)

	local nearpt = math3d.vector(0.0, 0.0, 1.0, 1.0)
	local farpt = math3d.vector(0.0, 0.0, 100.0, 1.0)

	local middlept = math3d.vector(0.0, 0.0, (1.0+100)*0.5, 1.0)
	local quadpt = math3d.vector(0.0, 0.0, (1.0+100)*0.25, 1.0)
	local pp0 = math3d.transform(invz_proj, nearpt, 1)
	local pp1 = math3d.transform(invz_proj, farpt, 1)
	local pp2 = math3d.transform(invz_proj, middlept, 1)
	local pp3 = math3d.transform(invz_proj, quadpt, 1)
	print "invz projection point:"
	print(math3d.tostring(pp0))
	print(math3d.tostring(pp1))
	print(math3d.tostring(pp2))
	print(math3d.tostring(pp3))

	print "projection point:"
	pp0 = math3d.transform(proj, nearpt, 	1)
	pp1 = math3d.transform(proj, farpt, 	1)
	pp2 = math3d.transform(proj, middlept, 	1)
	pp3 = math3d.transform(proj, quadpt, 1)

	print(math3d.tostring(pp0))
	print(math3d.tostring(pp1))
	print(math3d.tostring(pp2))
	print(math3d.tostring(pp3))
end

local math3d = require "math3d"

local ref1 = math3d.ref()

ref1.m = { s = 10, r = { axis = {1,0,0}, r = math.rad(60) },  t = { 1,2,3 } }

local ref2 = math3d.ref()

ref2.v = math3d.vector(1,2,3)

print(ref1)
print(ref2)

print "===SRT==="
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
ref1.s = 1
print_srt()
ref1.s = { 3,2,1 }
print_srt()

print "===QUAT==="

local ref3 = math3d.ref()
ref3.m = math3d.quaternion { axis = {1,0,0}, r = math.rad(60) } -- init mat with quat
print(ref3)
ref3.q = ref3	-- convert mat to quat
print(ref3)

print "===FUNC==="
print(ref2)
ref2.v = math3d.add(ref2,ref2,ref2)
print(ref2)
ref2.v = math3d.mul(ref2, 2.5)
print("length", ref2, "=", math3d.length(ref2))
print("floor", ref2, "=", math3d.tostring(math3d.floor(ref2)))
print("dot", ref2, ref2, "=", math3d.dot(ref2, ref2))
print("cross", ref2, ref2, "=", math3d.tostring(math3d.cross(ref2, ref2)))
print("mulH", ref1, ref2, "=", math3d.tostring(math3d.mulH(ref1, ref2)))
print("normalize", ref2, "=", math3d.tostring(math3d.normalize(ref2)))
print("normalize", ref3, "=", math3d.tostring(math3d.normalize(ref3)))
print("transpose", ref1, "=", math3d.tostring(math3d.transpose(ref1)))
print("inverse", ref1, "=", math3d.tostring(math3d.inverse(ref1)))
print("inverse", ref2, "=", math3d.tostring(math3d.inverse(ref2)))
print("inverse", ref3, "=", math3d.tostring(math3d.inverse(ref3)))
print("reciprocal", ref2, "=", math3d.tostring(math3d.reciprocal(ref2)))

print "===VIEWPROJ===="
local viewmat, projmat, p = math3d.view_proj({viewdir={0, 0, 1}, eyepos={0, 0, -8}}, {fov=90, aspect=1, n=1, f=1000}, true)
print("VIEW", math3d.tostring(viewmat))
print("PROJ", math3d.tostring(projmat))
print("VIEWPROJ", math3d.tostring(p))

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
print(vector(ref2, math3d.vector{1,2,3}))
print(matrix1(ref1))
print(matrix2(ref1,ref1))
print(matrix(ref1,ref1))
print(var(ref1))
print(var(ref2))
print(format("mv", ref1, ref2))
local m,v, q = mvq()
print(math3d.tostring(m), math3d.tostring(v), math3d.tostring(q))
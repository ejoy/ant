_DEBUG = 100 -- dectect memory leak

local math3d = require "math3d"
--[[
	local vec = math3d.ref "vector"	-- new vector ref object
	local mat = math3d.ref "matrix"	-- new matrix ref object

	= : assign an object to a ref object
	P : pop and return id ( ... , 1 -> ... )
	m : pop and return matrix pointer ( ... , 1 -> ... )
	V : top to string for debug ( ... -> ... )
	T : pop stack elem to lua
	1-9 : dup stack index (..., 1 -> ..., 1,1)
		1 : (..., 1 -> ..., 1,1)
		2 : (..., 2, 1 -> ..., 2, 1, 2)
		...
		9 : (...,9,8,7,6,5,4,3,2,1 -> ... , 9,8,7,6,5,4,3,2,1,9)
		22 means ( ..., a, b -> ..., a, b, a, b)
	S : swap stack top (..., 1,2 -> ..., 2,1 )
	R : remove stack top ( ..., 1 -> ... )
	d : convert rotation vec to view direcion	-- rotation vec is vec4 and x for rotating x-axis, y for rotatiing y-axis, z for rotatiing z-axis
	D : convert view direction to rotation vec

	{ 1,2,3,4 }	  push vector4(1,2,3,4)
	{ 1,2,3,4, .... 16 } push matrix4x4
	{} push identity matrix
	{ s = 2 } push scaled matrix (2,2,2)
	{ sx = 1, sy = 2, sz = 3 }
	{ rx = 1, ry = 0, rz = 0 }
	{ tx = 0, ty = 0 , tz = 1 }

	{ type = "mat", fov = 60, aspect = 1024/768 , n = 0.1, f = 100, }	-- proj mat
	{ type = "mat", l = 0, r = 1, b = 1, t = 0, n = 0, f = 100, ortho = true, h = false } -- ortho mat
	{ type = "quat", 0, 0, 0, 1}	-> quaternion, for x, y, z, w
	{ type = "quat", axis = {0, 0, 0}, radian = 60} -> quaternion from axis and angle
	* matrix mul ( ..., 1,2 - > ..., 1*2 )
	* vector4 * matrix4x4 / vec4 * vec4 / quat * quat / quat * vec4
	+ vector4 + vector4 ( ..., 1,2 - > ..., 1+2 )
	- vec4 - vec4 ( ..., 1,2 - > ..., 1-2 )
	. vec3 * vec3  ( ..., 1,2 -> ..., { dot(1,2) , 0 , 0 ,1 } )
	% vec4 * matrix4x4 -> vec4 /= vec4.w
	~ matrix to scale/rotation(rad)/tranlste (..., mat -> ... t, r, s)
	x cross (vec3 , vec3) ( ..., 1, 2, -> ... , cross(1,2) )
	i inverted matrix  ( ..., 1 -> ..., invert(1) )
	t transposed matrix ( ..., 1 -> ..., transpose(1) )
	n normalize vector3 ( ..., 1 -> ..., {normalize(1) , 1} )
	l generate lookat matrix ( ..., eye, at -> ..., lookat(eye,at) )
	e vec4/vec3/matrix to euler angle (v, "e")
	b extract matrix base orthogonal axis[xyz]
]]

local stackobj = math3d.new()

local stack = stackobj:command()
--	stack is the same as stackobj
--  stack(...) is equivalent to debug.getmetatable(stackobj).__call(stackobj, ...)

-- NOTICE: don't use mathed.ref directly, or we should remember call math3d.unref(refobj) or refobj(nil)

local quat = stackobj:ref "quaternion" {type='q', 0, 0, 0, 1}
math3d.reset(stackobj)
print(stack(quat, "V"))

local vec = math3d.ref "vector"
local mat = math3d.ref "matrix"	-- matrix ref

do
	local line1 = stackobj:vector()	-- (0,0,0,1)
	local line2 = stackobj:vector(1,2,3)	-- (1,2,3,0)
	local line3 = stackobj:vector(4,5,6,7)
	local line4 = stackobj:vector(8,9,10,11)
	local mat1 = stackobj:matrix(line1,line2,line3,line4)
	print(stack(mat1, "VR"))
	local mat1 = stackobj:matrix(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16)
	print(stack(mat1, "VR"))

	mat1 = stackobj:matrix() -- (1,0,0,0,  0,1,0,0,  0,0,1,0,  0,0,0,1)
	print(stack(mat1, "VR"))


	local q0 = stackobj:quaternion(0, 0, 0, 1)
	local q1 = stackobj:quaternion()
	print(stack(q0, "VR"))
	print(stack(q1, "VR"))
end

-- # turn on log
local v = stack("#", { type = "mat", fov = 60, aspect = 1024/768 } , "VR")	-- make a proj mat
print(v)

local orthmat = stack({type="m", l=-1, r=1, t=1, b=-1, n=1, f=1000, ortho=true}, "V")	-- make a ortho mat
print(orthmat)

stack( "#", vec, stackobj:vector( 1,2,3,1 ) , "1+=")	-- dup {1,2,3,4} add self and then assign to vec

local vv = stack({1, 2, 3, 1}, {2}, "*V")
print("vec4 mul : " .. vv)
print("unpack", stack("#>VRVRVRVR"))	-- unpack top {1*2,2*2,3*2,1*2} -> 2,4,6,2

-- pop to lua
stack({1, 2, 3, 1})
local data = stack("T")
assert(type(data) == "table")
assert(data.type ~= nil)
print("data.type : ", data.type)
for k,v in ipairs(data) do
	print("k : ", k, ", v : ", v)
end

--rotation view vector
do
	local zdir = stack(stackobj:euler2quat{math.rad(60), math.rad(30), 0, 0}, "dP")
	print("zdir : ", stack(zdir, "V"))
	local rot = stack(zdir, "DP")
	print("rot : ", stack(rot, "V"))

	print(stack(stackobj:forward_dir(stackobj:matrix(), "V")))
end

--quaternion
local quat_aa = stack({type = "quat", axis = {0, 1, 0}, radian = {math.rad(60)}}, "V")	--
print("quaternion with axis and angle : " .. quat_aa)

local quat_mul = stack({type = "quat", 0, 1, 0, 1}, {type = "quat", 1, 0, 0, 0.5}, "*V")	-- define an indentity quaternion
print("q * q : " .. quat_mul)

local quat_vec_mul = stack({1, 2, 3, 0}, {type = "quat", 0, 1, 0, 0.5}, "*V")
print("q * v : " .. quat_vec_mul)

local axisid = stack({1, 0, 0, 0}, "P")
print("axisid : ", axisid)
local qq = stack({type = "quat", axis = axisid, radian = {math.rad(60)}}, "V")
print("quaternion axis angle : ", qq)


--quaternion and euler
local q = stackobj:euler2quat {math.rad(90), 0, 0}
local e = stackobj:quat2euler(q)

print(stack(e, "V"))

--lookat
stack(mat, "1=")	-- init mat to an indentity matrix (dup self and assign)

local vH = stack(mat, {2, 4, 5, 1}, "%P")
print("vector homogeneous divide : ", stack(vH, "%V"))

local lookat = stack({0, 0, 0, 1}, {0, 0, 1, 0}, "lP")	-- calc lookat matrix
mat(lookat) -- assign lookat matrix to mat
print("lookat matrix : " , mat)
print(math3d.type(mat))	-- matrix true (true means marked)

local vec0 = math3d.ref "vector"
stack(vec0, {1, 2, 3, 4}, "=")	-- assign value to vec0

math3d.reset(stack)
print(vec, ~vec)	-- string and lightuserdata
mat(nil)	-- clear mat

local t = stack(vec, "P")
print(math3d.type(t))	-- vector true

print(stack(math3d.constant "identvec", "VR"))
print(stack(math3d.constant "identmat", "V"))	-- R: remove top
print(stack(">RRSRV"))	-- unpack ident mat, get 2st line, 1: RRR 2: RRSR 3:RSRSR 4:SRSRSR


-- srt object
do
	print "=====SRT====="
	local srt = stack({type="srt", s={0.01}, r=stackobj:euler2quat{math.rad(60), math.rad(60), math.rad(-30)}, t={0, 0, 0}}, "P")
	print("srt : ", stack(srt, "VR"))
	stack(srt, "~")
	local s = stack("P")
	local r = stack("P")
	local t = stack("P")
	print("s : ", stack(s, "VR"))
	print("r : ", stack(r, "VR"))
	print("t : ", stack(t, "VR"))

	local q1 = stack(srt, "qP")
	local e1 = stackobj:quat2euler(q1)
	print("e : ", stack(e1, "VR"))

	local mat = stackobj:srtmat(srt)

	print("to mat :", stack(mat , "VR"))
	print("to srt :", stack(stackobj:srt(mat), "VR"))

	print("scale(2) * scale(3) : ", stack(stackobj:srt { s = {2} } , stackobj:srt { s = {3} }, "*VR"))
	print("scale(2) * scalemat(3) : ", stack(stackobj:srt { s = {2} } , stackobj:srtmat { s = {3} }, "*VR"))
	print("scalemat(2) * scale(3) : ", stack(stackobj:srtmat { s = {2} } , stackobj:srt { s = {3} }, "*VR"))

	local srtref = math3d.ref "srt"

	stack(srtref, srt, "=")

	stack(srtref:pack( {0.1}, nil , nil))
	stack(srtref:unpack())
	print("Ref srt", stack("3VR2VR1VRRRR"))

	math3d.unref(srtref)
end

-- direction to euler
print "=====DIRECTION====="
do
	local rot = stack({1, 1, 1, 0}, "nDT")
	local dir = stack(rot, "dT")
	print(rot[1],rot[2],rot[3])
	print(dir[1],dir[2],dir[3])
end



--euler to quaternion
do
	local q1 = stackobj:euler2quat{0, math.rad(90), 0}
	print("quaternion", stack(q1, "VR"))

	local q2 = stack({type="q", axis={0, 1, 0}, radian={math.rad(90)}}, "P")
	print("quaternion 1 : ", stack(q2, "VR"))

	local e1 = stackobj:quat2euler(q1)
	print("euler : ", stack(e1, "VR"))
end

do
	-- extract base axis
	local lookat = stack({0, 0, 0, 1}, {0, 0, 1, 0}, "LP")
	local x, y, z = stack(lookat, "bPPP")
	print(stack(x, y, z, "VRVRVR"))
end

do
	-- AABB
	print("AABB", stack( {-1,-2,-3, 1}, "V", {4,5,6,1} , "V", stackobj.fromAABB , "V" ))
	print("AABB", stack( {1,1,1, 1}, "V", {5,5,5,1} , "V", stackobj.fromAABB , "V" ))
	print("Insect", stack( "22", stackobj.intersectAABB))
	print("Insert Plane {0,1,0,0}", stack( "2V", { 0,1,0,0 }, stackobj.intersectAABB))
	print("Insert Plane {0,1,0,0}", stack( "1V", { 0,1,0,0 }, stackobj.intersectAABB))
	print("mergeAABB (min,max)", stack( stackobj.mergeAABB, stackobj.toAABB , "SVRVR" ))
end

print("Memory = ", stackobj:stacksize())

do
	local tempvec = math3d.ref "vector"
	stack( tempvec, stackobj:vector( 1,2,3,4 ) , "=")
--	math3d.unref(tempvec)
end

-- tempvec is leak
collectgarbage "collect"
local leaks = stackobj:leaks()
if leaks then
	for _, id in ipairs(leaks) do
		print("Leaks : ", stack(id, "V"))
	end
end

math3d.unref(vec0)
math3d.unref(vec)
math3d.unref(mat)
math3d.unref(quat)

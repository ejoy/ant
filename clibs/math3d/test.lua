local math3d = require "math3d"
--[[
	local vec = math3d.ref "vector"	-- new vector ref object
	local mat = math3d.ref "matrix"	-- new matrix ref object

	= : assign an object to a ref object

	P : pop and return id ( ... , 1 -> ... )
	v : pop and return vector4 pointer ( ... , 1 -> ... )
	m : pop and return matrix pointer ( ... , 1 -> ... )
	f : pop and return the first float of a vector4 ( ... , 1 -> ... )
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

	{ 1,2,3,4 }	  push vector4(1,2,3,4)
	{ 1,2,3,4, .... 16 } push matrix4x4
	{} push identity matrix
	{ s = 2 } push scaled matrix (2,2,2)
	{ sx = 1, sy = 2, sz = 3 }
	{ rx = 1, ry = 0, rz = 0 }
	{ tx = 0, ty = 0 , tz = 1 }

	{ type = "proj", fov = 60, aspect = 1024/768 , n = 0.1, f = 100 }	-- proj mat
	{ type = "ortho", l = 0, r = 1, b = 1, t = 0, n = 0, f = 100, h = false } -- ortho mat
	{ type = "quat", 0, 0, 0, 1}	-> quaternion, for x, y, z, w
	{ type = "quat", axis = {0, 0, 0}, angle = 60} -> quaternion from axis and angle
	* matrix mul ( ..., 1,2 - > ..., 1*2 )
	* vector4 * matrix4x4 / vec4 * vec4 / quat * quat / quat * vec4
	+ vector4 + vector4 ( ..., 1,2 - > ..., 1+2 )
	- vec4 - vec4 ( ..., 1,2 - > ..., 1-2 )
	. vec3 * vec3  ( ..., 1,2 -> ..., { dot(1,2) , 0 , 0 ,1 } )
	x cross (vec3 , vec3) ( ..., 1, 2, -> ... , cross(1,2) )
	i inverted matrix  ( ..., 1 -> ..., invert(1) )
	t transposed matrix ( ..., 1 -> ..., transpose(1) )
	n normalize vector3 ( ..., 1 -> ..., {normalize(1) , 1} )
	l generate lootat matrix ( ..., eye, at -> ..., lookat(eye,at) )
]]

local vec = math3d.ref "vector"
local mat = math3d.ref "matrix"	-- matrix ref

local stack = math3d.new()
local pitch = -45
local yaw = 0
local zdir = math3d.ref "vector"

stack(zdir, {0, 1, 1, 0}, "=")
local euler = stack(zdir, "e", {type="e", pitch, yaw, 0}, "+T")
assert(euler.type == 5)	--LINEAR_TYPE_EULER
-- euler[1] = mu.limit(euler[1], -89.9, 89.9)
-- euler[2] = mu.limit(euler[2], -179.9, 179.9)

stack(zdir, {0, 0, 1, 0}, {type="e", euler[1], euler[2], euler[3]}, "*=")
print(zdir)

-- local zdir_rotate = stack(zdir, {type="q", axis="y", angle={45}}, "*P")
-- print("before : ", stack(zdir, "V"),
-- 		"after : ", stack(zdir_rotate, "V"))

-- local v = stack( { type = "proj", fov = 60, aspect = 1024/768 } , "VR")	-- make a proj mat
-- print(v)
-- local v1,m1 = stack( { s = 2 } , "VP" )	-- push scale 2x matrix
-- print(v1,m1)
-- local v2,m2 = stack( { rx = 1 } , "VP" )	-- push rot (1,0,0) matrix
-- print(v2,m2)
-- local m = stack(m1,m2,"*V")
-- print(m)

-- stack( vec, { 1,2,3,4 } , "1+=")	-- dup {1,2,3,4} add self and then assign to vec

-- local vv = stack({1, 2, 3, 1}, {2}, "*V")
-- print("vec4 mul : " .. vv)
-- print("unpack", stack(">VRVRVRVR"))	-- unpack top {1*2,2*2,3*2,1*2} -> 2,4,6,2

-- -- pop to lua
-- stack({1, 2, 3, 1})
-- local data = stack("T")
-- assert(type(data) == "table")
-- assert(data.type ~= nil)
-- print("data.type : ", data.type)
-- for k,v in ipairs(data) do
-- 	print("k : ", k, ", v : ", v)
-- end

-- --quaternion
-- local quat_aa = stack({type = "quat", axis = {0, 1, 0}, angle = {60}}, "V")	--
-- print("quaternion with axis and angle : " .. quat_aa)

-- local quat_mul = stack({type = "quat", 0, 1, 0, 1}, {type = "quat", 1, 0, 0, 0.5}, "*V")	-- define an indentity quaternion
-- print("q * q : " .. quat_mul)

-- local quat_vec_mul = stack({1, 2, 3, 0}, {type = "quat", 0, 1, 0, 0.5}, "*V")
-- print("q * v : " .. quat_vec_mul)

-- local axisid = stack({1, 0, 0}, "P")
-- print("axisid : ", axisid)
-- local qq = stack({type = "quat", axis = axisid, angle = {60}}, "V")
-- print("quaternion axis angle : ", qq)


-- --lookat
-- stack(mat, "1=")	-- init mat to an indentity matrix (dup self and assign)

-- local lookat = stack({0, 0, 0, 1}, {0, 0, 1, 0}, "lP")	-- calc lookat matrix
-- mat(lookat) -- assign lookat matrix to mat
-- print("lookat matrix : " , mat)
-- print(math3d.type(mat))	-- matrix true (true means marked)

-- local vec0 = math3d.ref "vector"
-- stack(vec0, {1, 2, 3, 4}, "=")	-- assign value to vec0

-- math3d.reset(stack)
-- print(vec, ~vec)	-- string and lightuserdata
-- mat()	-- clear mat

-- local t = stack(vec, "P")
-- print(math3d.type(t))	-- vector true
-- print(stack( t,"Vv"))	-- string lightuserdata

-- print(stack(math3d.constant "identvec", "VR"))
-- print(stack(math3d.constant "identmat", "V"))	-- R: remove top
-- print(stack(">RRSRV"))	-- unpack ident mat, get 2st line, 1: RRR 2: RRSR 3:RSRSR 4:SRSRSR

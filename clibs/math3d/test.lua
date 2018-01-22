local math3d = require "math3d"
--[[
	P : pop and return id ( ... , 1 -> ... )
	v : pop and return vector4 pointer ( ... , 1 -> ... )
	m : pop and return matrix pointer ( ... , 1 -> ... )
	f : pop and return the first float of a vector4 ( ... , 1 -> ... )
	V : top to string for debug ( ... -> ... )
	D : dup stack top (..., 1 -> ..., 1,1)
	S : swap stack top (..., 1,2 -> ..., 2,1 )
	R : remove stack top ( ..., 1 -> ... )
	M : mark stack top and pop ( ..., 1 -> ...)

	{ 1,2,3,4 }	  push vector4(1,2,3,4)
	{ 1,2,3,4, .... 16 } push matrix4x4
	{} push identity matrix
	{ s = 2 } push scaled matrix (2,2,2)
	{ sx = 1, sy = 2, sz = 3 }
	{ rx = 1, ry = 0, rz = 0 }
	{ tx = 0, ty = 0 , tz = 1 }

	{ type = "proj", fov = 60, aspect = 1024/768 , n = 0.1, f = 100 }	-- proj mat
	{ type = "ortho", l = 0, r = 1, b = 1, t = 0, n = 0, f = 100, h = false } -- ortho mat
	* matrix mul ( ..., 1,2 - > ..., 1*2 )
	* vector4 * matrix4x4
	+ vector4 + vector4 ( ..., 1,2 - > ..., 1+2 )
	- vec4 - vec4 ( ..., 1,2 - > ..., 1-2 )
	. vec3 * vec3  ( ..., 1,2 -> ..., { dot(1,2) , 0 , 0 ,1 } )
	x cross (vec3 , vec3) ( ..., 1, 2, -> ... , cross(1,2) )
	i inverted matrix  ( ..., 1 -> ..., invert(1) )
	t transposed matrix ( ..., 1 -> ..., transpose(1) )
	n normalize vector3 ( ..., 1 -> ..., {normalize(1) , 1} )
]]

local stack = math3d.new()

local v = stack( { type = "proj", fov = 60, aspect = 1024/768 } , "VR")	-- make a proj mat
print(v)
local v1,m1 = stack( { s = 2 } , "VP" )	-- push scale 2x matrix
print(v1,m1)
local v2,m2 = stack( { rx = 1 } , "VP" )	-- push rot (1,0,0) matrix
print(v2,m2)
local m = stack(m1,m2,"*V")
print(m)

local t = stack( { 1,2,3,4 } , "D+M")	-- dup {1,2,3,4} add self and mark result

math3d.reset(stack)

t = stack( t,"V")	-- read
print(t)

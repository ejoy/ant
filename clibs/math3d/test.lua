local math3d = require "math3d"
--[[
	P : pop and return id
	v : pop and return vector4 pointer
	m : pop and return matrix pointer
	V : top to string for debug
	D : dup stack top (1 -> 1,1)
	S : swap stack top ( 1,2 -> 2,1 )
	R : remove stack top ( 1 -> )
	M : mark stack top and pop

	{ 1,2,3,4 }	  push vector4(1,2,3,4)
	{ 1,2,3,4, .... 16 } push matrix4x4
	{} push indenty
	{ s = 2 } push scale 2,2,2
	{ sx = 1, sy = 2, sz = 3 }
	{ rx = 1, ry = 0, rz = 0 }
	{ tx = 0, ty = 0 , tz = 1 },

	* matrix mul ( 1, 2 - > 1*2 )
	* vector4 * matrix4x4
	+ vector4 + vector4
	- vec4 - vec4
	. vec3 * vec3  ( 1,2 -> (result, 0,0,1) )
	x cross (vec3 , vec3)
	i
	t
	n
]]

local stack = math3d.new()

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

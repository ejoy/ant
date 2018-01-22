local math3d = require "math3d"

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

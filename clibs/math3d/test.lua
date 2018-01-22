local math3d = require "math3d"

local stack = math3d.new()

local t = stack( { 1,2,3,4 } , "D+M")	-- dup {1,2,3,4} add self and mark result

math3d.reset(stack)

t = stack( t,"T")	-- read

for _, v in ipairs(t) do
	print(v)
end

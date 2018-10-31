local mymath = require "mymath"

local v = mymath:perspective_FovAspect(60, 1024/768):tostring()	-- make a perspective preps
print(v)

local orthmat = mymath:ortho(-1, 1, 1, -1, 1, 1000):tostring()	-- make a ortho mat
print(orthmat)

local vec = mymath:new_vec_ref()

mymath:push({1,2,3,4 }):duplicate(1):add():assign(vec)
print("ref vec value : ", vec)

local vv = mymath:mul({1, 2, 3, 1}, {2}):tostring()
print("vec4 mul : " .. vv)
--print("unpack", stack("#>VRVRVRVR"))	-- unpack top {1*2,2*2,3*2,1*2} -> 2,4,6,2

-- pop to lua
local data = mymath:push({1, 2, 3, 1}):totable()
assert(type(data) == "table")
assert(data.type ~= nil)
print("data.type : ", data.type)
for k,v in ipairs(data) do
	print("k : ", k, ", v : ", v)
end

--rotation view vector
do
	local zdirvalue = mymath:to_forward({60, 30, 0, 0}):tostring()
	print("zdir : ", zdirvalue)
	local rotation = mymath:to_rotation():tostring()
	print("rot : ", rotation)
end

--quaternion
local quat_aa = mymath:push({type = "quat", axis = {0, 1, 0}, angle = {60}}):tostring()
print("quaternion with axis and angle : " .. quat_aa)

local quat_mul = mymath:mul({type = "quat", 0, 1, 0, 1}, {type = "quat", 1, 0, 0, 0.5}):tostring()	-- define an indentity quaternion
print("q * q : " .. quat_mul)

local quat_vec_mul = mymath:mul({1, 2, 3, 0}, {type = "quat", 0, 1, 0, 0.5}):tostring()
print("q * v : " .. quat_vec_mul)

local axisid = mymath:push({1, 0, 0}):pop()
print("axisid : ", axisid)
local qq = mymath:mul({type = "quat", axis = axisid, angle = {60}}):tostring()
print("quaternion axis angle : ", qq)

--euler
local zdir = mymath:push({0, 0, 1, 0}):pop()
local e0 = mymath:to_euler(zdir):pop()
local e1 = mymath:add(e0, {type="e", pitch=-45, yaw=10, roll=0}):pop()
local e_m_dir = mymath:mul(e1, zdir):tostring()
print("zdir after rotate : ", e_m_dir)

--lookat
local mat = mymath:new_mat_ref()
mymath:push(mat):assign(mat)	-- init mat to an indentity matrix (dup self and assign)

mymath:mulH({2, 4, 5, 1}, mat)
print("vector homogeneous divide : ", mymath:tostring())

local lookat = mymath:lookat({0, 0, 0, 1}, {0, 0, 1, 0}):pop()	-- calc lookat matrix
mat(lookat) -- assign lookat matrix to mat

print("lookat matrix : " , mat)
--print(math3d.type(mat))	-- matrix true (true means marked)

local vec0 = mymath:new_vec_ref()
mymath:assign(vec0, {1, 2, 3, 4})	-- assign value to vec0

mymath:reset()
print(vec0, ~vec0)	-- string and lightuserdata
mat()	-- clear mat

local t = mymath:push(vec):pop()
--print(math3d.type(t))	-- vector true

-- print(stack(math3d.constant "identvec", "VR"))
-- print(stack(math3d.constant "identmat", "V"))	-- R: remove top
-- print(stack(">RRSRV"))	-- unpack ident mat, get 2st line, 1: RRR 2: RRSR 3:RSRSR 4:SRSRSR


-- matrix to srt
do
	local srt = mymath:push({type="srt", s={0.01}, r={60, 60, -30}, t={0, 0, 0}}):pop()
	mymath:decompose_mat(srt)
	
	print("s : ", mymath:tostring())
	mymath:pop()
	print("r : ", mymath:tostring())
	mymath:pop()
	print("t : ", mymath:tostring())
	mymath:pop()

	mymath:to_euler(srt)	-- current stack top is srt matrix
	print("matrix to euler : ", mymath:tostring())

	mymath:to_euler({type="q", math.cos(math.pi * 0.25), 0, 0, math.sin(math.pi * 0.25)})
	print("quaterion to euler : ", mymath:tostring())

	-- local q = stack(e1, "qP")
	-- print("e to q : ", stack(q, "V"))


end

-- direction to euler
do
	local rot = mymath:normalize({1, 1, 1}):to_rotation():totable()
	local dir = mymath:to_forward(rot)
	print(rot)
	print(dir)
end



--euler to quaternion
do
	local q = mymath:to_quaternion({0, 90, 0})
	print("quaternion", mymath:tostring())

	mymath:push({type="q", axis={0, 1, 0}, angle={90}})
	print("quaternion 1 : ", mymath:tostring())

	mymath:to_euler()
	print("euler : ", mymath:tostring())
end

do
	-- extract base axis
	mymath:lookat({0, 0, 0}, {0, 0, 1}):rotation_to_axis()
	
	for _, n in ipairs {"x : ", "y : ", "z : "} do
		print(n, mymath:tostring())
		mymath:pop()
	end
end




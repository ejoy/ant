local skeleton     = require "hierarchy".skeleton
local math3d        = require "math3d"
local math3d_adapter= require "math3d.adapter"

local root          = skeleton.new()
local nmt           = skeleton.node_metatable()

nmt.add_child       = math3d_adapter.format(nmt.add_child, "vqv", 3)
nmt.transform       = math3d_adapter.getter(nmt.transform, "vqv")
nmt.set_transform   = math3d_adapter.format(nmt.set_transform, "vqv", 1)

local s, r, t = 
    math3d.vector(2, 1, 0.5, 0.0), 
    math3d.quaternion(math.cos(math.rad(45)), 0, 0, math.sin(math.rad(45))),
    math3d.vector(2, 2, 2, 1)
local c = root:add_child("child", s, r, t)
print(c:name())
print(root:get_child(1):name())

local ss, rr, tt = c:transform()
print("root, s, r, t:", math3d.tostring(ss), math3d.tostring(rr), math3d.tostring(tt))

local child = root:get_child(1)
child:set_name "foobar"
collectgarbage "collect"

print(child:name())
local old = root:get_child(1)

local s1, r1, t1 = 
    math3d.ref(math3d.vector(1, 3, 0.1)), 
    math3d.ref(math3d.quaternion(math.cos(math.rad(45)), 0, 0, math.sin(math.rad(45)))), 
    math3d.ref(math3d.vector(2, 2, 1))

root:add_child("child2", s1.p, r1.p, t1.p)

local new = root:get_child(2)

root:remove_child(1)

print("root children num : ", #root)

for i=1, #root do
	print("===>", i, root:get_child(i):name())
end

print(skeleton.invalid(new))	-- Invalid node
print(skeleton.invalid(old))

-- will rasie an error
--print(old.name)	-- Invalid node

--child[1] = { name = "child_1"}

child = root:get_child(1)

local child_1 = child:get_child(1)
assert(child_1 == nil)
child:add_child("child_1")

child_1 = child:get_child(1)
assert(child_1 ~= nil)
print(child_1:name())

child:add_child("child_2")
assert(child_1 ~= nil)
child_1:add_child("child_1_1")


local function print_tree(tr, offset_pr)
    local num = #tr
    if num == 0 then
        return 
    end

    for i=1, num do
        local child = assert(tr:get_child(i))
        local child_num = #child

        print(offset_pr .. child:name())
        -- need math_adpater
        --local transform = child:transform()
        -- print(offset_pr .. "transform, scale : ", transform.s, 
        --     ", rotation : ", transform.r, 
        --     ", translation : ", transform.t)

        if child_num ~= 0 then
            print_tree(child, offset_pr .. "\t")
        end
    end    
end

print('-------------------------------')
print_tree(root, "")


print('===============================')

local function print_build(tr)
    local result = skeleton.build(tr);
    for idx, vv in ipairs(result) do
        print("idx in result : ", idx)
        print("value ");
        for k, v in pairs(vv) do
            print(k, v)
        end
    end
end

print_build(root)
assert(skeleton.invalid(new))	-- Invalid node

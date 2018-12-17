
local bullet_module = require "bullet"

local bullet = bullet_module.new()
local btworld = bullet:new_world()
local bu = require "lua.util"


local shapes = {
	cylinder = btworld:new_shape("cylinder", 6, 2, 1),
	plane = btworld:new_shape("plane", 0, -1, 1, 3),
	sphere = btworld:new_shape("sphere", 5),
	capsule = btworld:new_shape("capsule", 2, 6, 1),
	compound = btworld:new_shape("compound"),
}

local function get_user_idx_op()
	local start_user_idx = 100
	return function ()
		local t = start_user_idx 
		start_user_idx = start_user_idx + 1
		return t
	end
end

local gen_user_idx = get_user_idx_op()

local useridx = gen_user_idx()
local object_plane = btworld:new_obj(shapes.plane, useridx, {0,0,0}, {0,0,0,1})
btworld:add_obj(object_plane)


btworld:add_to_compound(shapes.compound, shapes.sphere, {0,0,0},{90,0,0,1})

local compound_idx = gen_user_idx()
local compound_obj = btworld:new_obj(shapes.compound, compound_idx, {2,2,2},{45,0,0,1})

local radius = 1
local num_compounds = 5
local num_spheres = 1

local objs = {} 
 
for i = 1, num_compounds do 
    local compound_shape = bu.create_compoundShape(btworld)
    for j = 1, num_spheres do 
       local pos = { j*1.5, 0, 0 }
	   local rot = { 0, 0, 0, 1 }
       local child_shape = bu.create_sphereShape(btworld, radius)
       btworld:add_to_compound(compound_shape, child_shape, pos, rot)
    end 
    -- object
    local pos = { i*1*1.5, -2.4, 0 }
	local rot = { 0, 0, 0, 1}
	local idx = gen_user_idx()
	local object = btworld:new_obj(compound_shape, idx, pos, rot)
	btworld:add_obj(object)        
    objs[i] = object 
end 
  

------- do collision check ---------
print("world collide begin ----")

local function print_collide_points(points)
	for _, pt in ipairs(points) do
        print("point A in world:", 	pt.ptA_in_WS[1], 	pt.ptA_in_WS[2], 	pt.ptA_in_WS[3])
        print("point B in world:", 	pt.ptB_in_WS[1],	pt.ptB_in_WS[2],	pt.ptB_in_WS[3])
        print("normal B in world:", pt.normalB_in_WS[1],pt.normalB_in_WS[2],pt.normalB_in_WS[3])
        print("distance:", 			pt.distance)        		
	end
end

local collide_points = {}
-- lua callback 
-- 这样使用回调的方式
-- 1. 复杂度较高，对lua使用者稍不友好，也容易出错
-- 2. 速度慢，多次的lua 回调，多次的创建回收points 表，再合并，维护开销大
-- 3. 没有终止约束条件
-- 4. 如果是回调方式，建议从名称上就体现
btworld:world_collide_ucb(function (objA, objB, userdata)
	assert(type(objA) == type(objB))	
	assert(type(objA) == "userdata")
	assert(type(userdata) == "userdata")
	local pts = btworld:collide_objects(objA, objB, userdata)
	if pts then
		for k,v in pairs(pts) do 
			table.insert(collide_points,v)
		end 
		--table.move(pts, 1, #pts, #collide_points, collide_points)
	end
end)
print("total points = ",#collide_points)
print_collide_points(collide_points)
print("world collide end ---")

print("")

-- 简单直接的另一个方法 
print("world collide begin 2 ======")
local points = btworld:world_collide()
if points then 
	print("world collide result : ", #points)
	print_collide_points(points)
end 
print("world collide end 2 ======")



--- collide between two objects ---
print("")
print("simple collide obj[1] to obj[2]")
local objAB_collide_points = btworld:collide_objects(objs[1], objs[2] )
if objAB_collide_points then 
    print("objA objB collide result : ", #objAB_collide_points)
    print_collide_points(objAB_collide_points)  
end 
print("");


-- raycast 
local rayFrom = { 1.5, 20, 0}
local rayTo = {  1.5, -5, 0 }
local hit, result = btworld:raycast(rayFrom, rayTo)

local function print_raycast_result(result)
	print("object user index : ", result.useridx)
	print("hit fraction :", result.hit_fraction)

	print("hit object point : ", result.hit_pt_in_WS[1], result.hit_pt_in_WS[2], result.hit_pt_in_WS[3])
	print("hit normal : ", result.hit_normal_in_WS[1], result.hit_normal_in_WS[2], result.hit_normal_in_WS[3])
	print("filter group : ", result.filter_group)
	print("filter mask : ", result.filter_mask)
	print("flags : ", result.flags)    
end
if hit then 
	print_raycast_result(result)
else 
    print("--- hit nothing, rayInfo = ", result )
end 

print("")
-- move up 3 unit
btworld:set_obj_transform(object_plane, {0,3,0}, {0,0,0,1})

local hit1, result1 = btworld:raycast(rayFrom,rayTo)

print("move plane to {0,3,0}")
if hit1 then     
    print_raycast_result(result1)
else 
    print("--- hit nothing, rayInfo = ", result1 )
end 

print("")
-- move up 6 unit
btworld:set_obj_position(object_plane, {0,6,0})
local hit2, result2 = btworld:raycast(rayFrom,rayTo)
if hit2 then 
    print("move plane to {0,6,0}")
    print_raycast_result(result2)
else 
    print("--- hit nothing, rayInfo = ", result2 )
end 
print("")

-- rotate 
local invRayFrom = { 1.5, 20, 0}
local invRayTo = {  1.5,  -20, 0 }
btworld:set_obj_position(object_plane, {0,0,0})
--btworld:set_obj_rotation(object_plane, {0.7,0,0.7,0})
--btworld:set_obj_rot_euler(object_plane,math.rad(0),math.rad(-180),math.rad(0) )
btworld:set_obj_rot_axis_angle(object_plane, {1,0,0}, math.rad(180) )
local hit3, result3 = btworld:raycast(invRayFrom,invRayTo)
if hit3  then 
    print("rotate plane to {0,-6,0}")
    print_raycast_result(result3)
else 
    print("--- hit nothing, rayInfo = ", result3 )
end 
print("")


print("")
-- collide between thin box and capsule 
local ent_box = gen_user_idx()
local ent_capsule = gen_user_idx()
local tshape_box = btworld:new_shape("cube", 3, 0.5, 3)
local tshape_capsule = btworld:new_shape("capsule", 2,6,1)
local tobj_box = btworld:new_obj(tshape_box, ent_box, {0,0,0},{0,0,0,1})
local tobj_capsule = btworld:new_obj(tshape_capsule, ent_capsule, {0,5.5,0},{0,0,0,1})

local box_capsule_points = btworld:collide_objects(tobj_box, tobj_capsule)
if box_capsule_points then 
    print("box and capsule collide, hit count is : ", #box_capsule_points)
    print_collide_points(box_capsule_points)
end 
print("")


-- quaternion above user-unfriendly
btworld:del_shape(shapes.sphere);
btworld:del_obj(tobj_box);

print("")

btworld = nil		-- gc world
bullet = nil		-- gc bullet sdk


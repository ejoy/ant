
package.path = table.concat(
	{
		"engine/?.lua",
		"packages/?.lua",
	}, ";"
)

package.cpath = "projects/msvc/vs_bin/Debug/?.dll"

local math3d 	= require "math3d"
local ms		= math3d.new()

local bt = require "bullet"
local btworld = bt.new()

local shapes = {
	cylinder 	= btworld:new_shape("cylinder", {radius=6, height=2, axis=1}),
	plane 		= btworld:new_shape("plane", {normal = {0, 1, 0}, distance=3}),
	sphere 		= btworld:new_shape("sphere", {radius = 5}),
	capsule 	= btworld:new_shape("capsule", {radius=2, height=6, axis=1}),
	compound 	= btworld:new_shape "compound",
	box 		= btworld:new_shape("box", {size={1, 1, 1}}),
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
local rot = ms({type='q', 0,0,0,1}, "m")
local object_plane = btworld:new_obj(shapes.plane, useridx)
btworld:set_obj_rotation(object_plane, rot)
btworld:add_obj(object_plane)

btworld:add_to_compound(shapes.compound, shapes.sphere)

local compound_idx = gen_user_idx()
local compound_obj = btworld:new_obj(shapes.compound, compound_idx, ms({2, 2, 2,1}, "m"), ms:euler2quat{math.rad(45),0,0})
btworld:add_obj(compound_obj)

local radius = 1
local num_compounds = 5
local num_spheres = 1

local objs = {} 
 
for i = 1, num_compounds do 
	local compound_shape = btworld:new_shape "compound"
	local ipos = i
    for j = 1, num_spheres do 
       local pos = ms({ipos, 0, j*1.5, 1}, "m")
       local child_shape = btworld:new_shape("sphere", {radius=radius})
       btworld:add_to_compound(compound_shape, child_shape, pos)
    end

	local object = btworld:new_obj(compound_shape,
					gen_user_idx(),
					ms({ipos, 0.0, 0, 1}, "m"))

	btworld:add_obj(object)
    objs[i] = object
end

local function print_collide_points(points)
	for _, pt in ipairs(points) do
        print("point A in world:", 	pt.ptA_in_WS[1], 	pt.ptA_in_WS[2], 	pt.ptA_in_WS[3])
        print("point B in world:", 	pt.ptB_in_WS[1],	pt.ptB_in_WS[2],	pt.ptB_in_WS[3])
        print("normal B in world:", pt.normalB_in_WS[1],pt.normalB_in_WS[2],pt.normalB_in_WS[3])
        print("distance:", 			pt.distance)
	end
end

print("world collide begin 2 ======")
local points = btworld:world_collide()
if points then
	print("world collide result : ", #points)
	print_collide_points(points)
end 
print("world collide end 2 ======")

print("simple collide obj[1] to obj[2]")
local objAB_collide_points = btworld:collide_objects(objs[1], objs[2] )
if objAB_collide_points then 
    print("objA objB collide result : ", #objAB_collide_points)
    print_collide_points(objAB_collide_points)
end
print("")


-- raycast 
local rayFrom = ms({ 1.5, 20, 0, 1}, "m")
local rayTo = ms({1.5, -5, 0, 1}, "m")

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
btworld:set_obj_transform(object_plane, ms({0,3,0}, "m"), ms({0,0,0,1}, "m"))

local hit1, result1 = btworld:raycast(rayFrom,rayTo)

print("move plane to {0,3,0}")
if hit1 then
    print_raycast_result(result1)
else
    print("--- hit nothing, rayInfo = ", result1 )
end

print("")
-- move up 6 unit
btworld:set_obj_position(object_plane, ms({0,6,0}, "m"))
local hit2, result2 = btworld:raycast(rayFrom,rayTo)
if hit2 then
    print("move plane to {0,6,0}")
    print_raycast_result(result2)
else
    print("--- hit nothing, rayInfo = ", result2 )
end
print("")

-- rotate 
local invRayFrom = ms({ 1.5, 20, 0}, "m")
local invRayTo = ms({1.5,  -20, 0 }, "m")
btworld:set_obj_position(object_plane, ms({0,0,0}, "m"))
--btworld:set_obj_rotation(object_plane, {0.7,0,0.7,0})
btworld:set_obj_rotation(object_plane, ms({type="q", axis={1,0,0}, radian={math.rad(180)}}, "m"))
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
local tshape_box = btworld:new_shape("box", {size={3, 0.5, 3}})
local tshape_capsule = btworld:new_shape("capsule", {radius=2, height=6, axis=1})
local tobj_box = btworld:new_obj(tshape_box, ent_box, ms({0,0,0}, "m"), ms({0,0,0,1}, "m"))
local tobj_capsule = btworld:new_obj(tshape_capsule, ent_capsule, ms({0,5.5,0}, "m"), ms({0,0,0,1}, "m"))

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

math3d.reset(ms)

btworld = nil


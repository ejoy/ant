local bullet_module = require "bullet2"

local bullet = bullet_module.new()
local btworld = bullet:new_world()

local shapes = {
	plane = btworld:new_shape("plane", 0,1,0,-3),
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
local object_plane = btworld:new_collision_obj(shapes.plane, useridx, {0,0,0}, {0,0,0,1})
btworld:add_collision_obj(object_plane)

-- print("plane",shape_plane)
-- print("sphere",shape_sphere)
-- print("capsule",shape_capsule)
-- print("compound",shape_compound)
-- print("")

btworld:add_to_compund(shapes.compound, shapes.sphere, {0,0,0},{90,0,0,1})

local compound_idx = gen_user_idx()
local compound_obj = btworld:new_collision_obj(shapes.compound, compound_idx, {2,2,2},{45,0,0,1})

local radius = 1
local num_compounds = 5
local num_spheres = 1

local objs = {} 
 
for i = 1, num_compounds do 
    local compound_shape = btworld:create_shape("compound")
    for j = 1, num_spheres do 
       local pos = { j*1.5, 0, 0 }
       local rot = { 0, 0, 0, 1 }
       local child_shape = btworld.create_shape("sphere", radius)
       btworld:add_to_compund(compound_shape, child_shape, pos, rot)
    end 
    -- object
    local pos = { i*1*1.5, -2.4, 0 }
	local rot = { 0, 0, 0, 1}
	local idx = gen_user_idx()
	local object = btworld:new_collision_obj(compound_shape, idx, pos, rot)
	btworld:add_collision_obj(object)        
    objs[i] = object 
end 
  
print("world collide begin ----")
print("")
local hit_count,points = bullet.worldCollide(sdk,world);
print("world collide end ---")
if hit_count > 0 then 
    print("collide multiObject in world: find ".. hit_count.."contact points")
    for i =1 ,hit_count do 
        print("point idx =",i)
        print("ptOnAWorld:",points[i].ptOnAWorld.x, points[i].ptOnAWorld.y, points[i].ptOnAWorld.z)
        print("ptOnBworld:",points[i].ptOnBWorld.x,points[i].ptOnBWorld.y,points[i].ptOnBWorld.z)
        print("normalOnB:",points[i].normalOnB.x,points[i].normalOnB.y,points[i].normalOnB.z)
        print("distance:",points[i].distance)        
     end 
end 

print("")

print("simple collide objA to objB")
hit_count ,points = bullet.collide(sdk,world, objs[1],objs[2] )
if hit_count > 0 then 
      print("collide a to b: find ".. hit_count.." points")
      for i =1 ,hit_count do 
          print("point idx =",i)
          print("ptOnAWorld:",points[i].ptOnAWorld.x, points[i].ptOnAWorld.y, points[i].ptOnAWorld.z)
          print("ptOnBworld:",points[i].ptOnBWorld.x,points[i].ptOnBWorld.y,points[i].ptOnBWorld.z)
          print("normalOnB:",points[i].normalOnB.x,points[i].normalOnB.y,points[i].normalOnB.z)
          print("distance:",points[i].distance)        
       end 
end 
print("");

-- raycast 
local rayFrom = { 1.5, 20, 0}
local rayTo = {  1.5, -5, 0 }
local hit, result = bullet.raycast(sdk,world,rayFrom,rayTo)
if hit == true  then 
    print("+++ hit object, entity id", result.hitObjId )
    print("hitFraction", result.hitFraction)
    print("hitNormalWorld",result.hitNormalWorld.x,
                           result.hitNormalWorld.y,
                           result.hitNormalWorld.z)
    print("hitPointWorld", result.hitPointWorld.x,
                           result.hitPointWorld.y,
                           result.hitPointWorld.z)
    print("filterGroup", result.filterGroup)
    print("filterMask", result.filterGroup)
else 
    print("--- hit nothing, rayInfo = ", result )
end 

print("")
-- move up 3 unit
bullet.set_collisionObjectTransform(sdk,world,object_plane ,{0,3,0},{0,0,0,1} )
hit, result = bullet.raycast(sdk,world,rayFrom,rayTo)
if hit == true  then 
    print("move plane to {0,3,0}")
    print("+++ hit object, entity id", result.hitObjId )
    print("hitFraction", result.hitFraction)
    print("hitNormalWorld",result.hitNormalWorld.x,
                           result.hitNormalWorld.y,
                           result.hitNormalWorld.z)
    print("hitPointWorld", result.hitPointWorld.x,
                           result.hitPointWorld.y,
                           result.hitPointWorld.z)

    if result.hitPointWorld.y > -0.000001 and result.hitPointWorld.y< 0.000001 then 
        print("equal zero")
    end 
    print("filterGroup", result.filterGroup)
    print("filterMask", result.filterGroup)
else 
    print("--- hit nothing, rayInfo = ", result )
end 

print("")
-- move up 6 unit
bullet.set_collisionObjectPos(sdk,world,object_plane,{0,6,0})
hit, result = bullet.raycast(sdk,world,rayFrom,rayTo)
if hit == true  then 
    print("move plane to {0,6,0}")
    print("+++ hit object, entity id", result.hitObjId )
    print("hitFraction", result.hitFraction)
    print("hitNormalWorld",result.hitNormalWorld.x,
                           result.hitNormalWorld.y,
                           result.hitNormalWorld.z)
    print("hitPointWorld", result.hitPointWorld.x,
                           result.hitPointWorld.y,
                           result.hitPointWorld.z)
    print("filterGroup", result.filterGroup)
    print("filterMask", result.filterGroup)
else 
    print("--- hit nothing, rayInfo = ", result )
end 
print("")

-- rotate 
local invRayFrom = { 1.5, -20, 0}
local invRayTo = {  1.5,   20, 0 }
bullet.set_collisionObjectRot(sdk,world,object_plane,{0.7,0,0.7,0})
hit, result = bullet.raycast(sdk,world,invRayFrom,invRayTo)
if hit == true  then 
    print("rotate plane to {0,-6,0}")
    print("+++ hit object, entity id", result.hitObjId )
    print("hitFraction", result.hitFraction)
    print("hitNormalWorld",result.hitNormalWorld.x,
                           result.hitNormalWorld.y,
                           result.hitNormalWorld.z)
    print("hitPointWorld", result.hitPointWorld.x,
                           result.hitPointWorld.y,
                           result.hitPointWorld.z)
    print("filterGroup", result.filterGroup)
    print("filterMask", result.filterGroup)
else 
    print("--- hit nothing, rayInfo = ", result )
end 
print("")

print("")
-- collide between thin box and capsule 
local entity = { "any entity" }
local ent_box = 10
local ent_capsule = 20
local tshape_box = bullet.create_cubeShape( sdk,world,{3,0.5,3} )
local tshape_capsule = bullet.create_capsuleShape( sdk,world,2,6,1)
local tobj_box = bullet.create_collisionObject(sdk,world,tshape_box,{0,0,0},{0,0,0,1}, ent_box, entity )
local tobj_capsule = bullet.create_collisionObject(sdk,world,tshape_capsule,{0,5.5,0},{0,0,0,1},ent_box,entity)

hit_count,points = bullet.collide(sdk,world, tobj_box, tobj_capsule )
if hit_count > 0 then 
    print("box hit capsule .."..hit_count.." contact points")
    for i =1 ,hit_count do 
        print("point idx =",i)
        print("ptOnAWorld:",points[i].ptOnAWorld.x, points[i].ptOnAWorld.y, points[i].ptOnAWorld.z)
        print("ptOnBworld:",points[i].ptOnBWorld.x,points[i].ptOnBWorld.y,points[i].ptOnBWorld.z)
        print("normalOnB:",points[i].normalOnB.x,points[i].normalOnB.y,points[i].normalOnB.z)
        print("distance:",points[i].distance)        
     end 
end 
print("")

-- quaternion above user-unfriendly

bullet.delete_shape(sdk,world,shape_sphere);
bullet.delete_collisionObject(sdk,world,object);

print("")
bullet.destroy_world( sdk,world )
bullet.exit_physics( sdk );

local bullet = require "bullet"


print(" ")
local sdk = bullet.init_physics()
local world = bullet.create_world( sdk )
print(" ")

local shape_plane  = bullet.create_planeShape( sdk, world,  0,1,0,-3  )
local shape_sphere = bullet.create_sphereShape( sdk, world, 5 )
local shape_capsule = bullet.create_capsuleShape( sdk,world,2,6,1)
local shape_compound = bullet.create_compoundShape( sdk,world) 

local entity_plane = { "plane entity " }
local object_plane = bullet.create_collisionObject(sdk,world,shape_plane,{0,0,0},{0,0,0,1},100, entity_plane )
bullet.add_collisionObject(sdk,world,object_plane)

print("plane",shape_plane)
print("sphere",shape_sphere)
print("capsule",shape_capsule)
print("compound",shape_compound)
print("")

bullet.add_shapeToCompound(sdk,world,shape_compound,shape_sphere,{0,0,0},{90,0,0,1} )

local entity_id = 100
local entity = {"entity"}
local object = bullet.create_collisionObject(sdk,world,shape_compound,{2,2,2},{45,0,0,1},entity_id,entity)

local radius = 1
local num_compounds = 5
local num_spheres = 1

local objs = {} 
 
for i = 1, num_compounds do 
    local compound_shape = bullet.create_compoundShape(sdk,world)
    for j = 1, num_spheres do 
       local pos = { j*1.5, 0, 0 }
       local rot = { 0, 0, 0, 1 }
       local child_shape = bullet.create_sphereShape(sdk,world,radius)
       bullet.add_shapeToCompound(sdk,world,compound_shape,child_shape,pos,rot)
    end 
    -- object
    local pos = { i*1*1.5, -2.4, 0 }
    local rot = { 0, 0, 0, 1}
    local object = bullet.create_collisionObject(sdk,world,compound_shape,pos,rot,i)
    bullet.add_collisionObject(sdk,world,object)
    -- table.insert( objs,object )
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

-- collider 碰撞体尝试设计 
-- 界面编辑和设计，bullet 根据 entity 和 component 创建关联
ecs.component "CapsuleCollider"
{
    center = {0,0,0},
    radius = 1,
    height = 8,
    axis = "Y",
    isTrigger = 0,
}

ecs.component "BoxCollider " 
{
    center = { 0,0,0 },
    size = { 1,1,1 },
    isTrigger = 0,        
}

ecs.component "SphereCollider"
{
    center = { 0,0,0 },
    radius = 1,
    isTrigger = 0,
}

ecs.component "MeshCollider" 
{
    Mesh = "tree.bin",
    Convex = 0,
    isTrigger = 0,
}


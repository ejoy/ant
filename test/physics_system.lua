--local ecs = ...
local world = ecs.world

--[ physics system stuff ]
-- move this to libs/physics directory 
-- physics function check samples 
-- if wanna do rigidbody simulate or anything extened,put it here in the future 



-- package.path = package.path..';./libs/terrain/?.lua;'
-- package.path = package.path..';./libs/bullet/?.lua;'

local bullet_world = require "bulletworld"

local math = import_package "ant.math"
local ms = math.stack

local phys_sys = ecs.system "physics_system"

-- phys_sys.singleton "math_stack"

--[ terrain tested ]
--local terrainClass = require "terrainclass"
--terrain = terrainClass.new() 

--local cube_obj,cube_shape
--local caps_obj,caps_shape 

function phys_sys:init()
    local Physics = world.args.Physics

    -- -- simple api test
    -- local shape_plane = Physics:create_planeShape(0,1,0,0)
    -- Physics:create_cylinderShape(6,2,1)
    -- Physics:create_sphereShape(5)
    -- Physics:create_capsuleShape(2,6,2)
    -- Physics:create_compoundShape()

    -- local obj_idx = 100
    -- Physics:new_shape("capsule",{ radius = 10} )    
    -- local object_plane = Physics:new_obj(shape_plane,obj_idx,{0,-100,0},{0,0,0,1} )
    -- Physics:add_obj(object_plane)


    -- -- user api test 
    -- obj_idx = 300
    -- local info = { isTrigger = 1, center = {0,10,0}, nx = 0, ny = 1, nz = 0, dist = 0, }
    -- Physics:create_collider( "plane",info, obj_idx, {0,-100,0}, {0,0,0,1} )

    -- terrain:load( "assets/build/terrain/pvp1.lvl" )
    -- obj_idx = 200
    -- local ter_info = {}
    -- Physics:create_terrainCollider(terrain,ter_info, obj_idx, {0,-120,0},{0,0,0,1}) 


    -- -- object collide test
    -- obj_idx = 10
    -- local cube_comp_info = { isTrigger =1, center = {0,0,0} ,sx=3,sy=0.5,sz=3 }
    -- cube_obj,cube_shape = Physics:create_collider("cube",cube_comp_info, obj_idx, {0,0,0}, {0,0,0,1})
    
    -- obj_idx = 20
    -- local capsule_comp_info = { isTrigger =1, center= {0,0,0}, radius = 2, height = 6, axis = 1 }
    -- caps_obj,caps_shape = Physics:create_collider("capsule",capsule_comp_info, obj_idx, {0,0,0}, {0,0,0,1} )

    -- obj_idx = 30
    -- local cy_comp_info = { isTrigger =1, center= {0,0,0}, radius = 2, height = 6, axis = 1 }
    -- local cy_obj,cy_shape = Physics:create_collider("cylinder",cy_comp_info, obj_idx, {0,0,0}, {0,0,0,1} )

    -- obj_idx = 40
    -- local sp_comp_info = { isTrigger =1, center={0,0,0}, radius = 2 }
    -- local sp_obj,sp_shape = Physics:create_collider("sphere",sp_comp_info,obj_idx,{0,0,0},{0,0,0,1} )

    -- obj_idx = 50
    -- local pl_comp_info = { isTrigger=1, center={0,0,0}, nx= 0,ny=1,nz=0,dist=1, dist = 0 }
    -- local pl_obj,pl_shape = Physics:create_collider("plane",pl_comp_info,obj_idx, {0,-100,0}, {0,0,0,1} )


end     

function phys_sys:update()
    local Physics = world.args.Physics
    
    if Physics == nil then  return  end 

    -- Physics:stepSimulator()

    -- [raycast select object sample]
    -- raycast and check entity is terrain or mesh etc 
    -- local rayFrom = {32.000001,1000,32}  -- { 100.5, 1000, 100.5 }
    -- local rayTo = {32.000001,-1000,32}  -- { 100.5, -1000, 100.5 }
    -- local hit, result = Physics:raycast(rayFrom, rayTo)

    -- if hit then  
    --     local ent = world[result.useridx]
    --     if ent.terrain then 
    --       local terrain = ent.terrain.terrain_obj
    --       local hit1,height1 = terrain:get_height( rayFrom[1],rayFrom[3] );
    --       --print("height1 = ", height1)    
    --     end 
    -- end 
    
    -- local print_r = function(name,x,y,z)
    --     print(name..": ", string.format("%08.4f",x), string.format("%08.4f",y), string.format("%08.4f",z) )
    -- end 
    -- local function print_raycast_result(result)
    --     print(  "object user index : ", result.useridx)
    --     print(  "     hit fraction : ", result.hit_fraction)
    
    --     print_r(" hit object point : ", result.hit_pt_in_WS[1], result.hit_pt_in_WS[2], result.hit_pt_in_WS[3])
    --     print_r("       hit normal : ", result.hit_normal_in_WS[1], result.hit_normal_in_WS[2], result.hit_normal_in_WS[3])
    --     print(  "     filter group : ", result.filter_group)
    --     print(  "      filter mask : ", result.filter_mask)
    --     print(  "            flags : ", result.flags)    
    -- end
    -- if hit then 
    --     print_raycast_result(result)
    -- else 
    --     print("--- hit nothing, rayInfo = ", result )
    -- end  

    -- [collide_objects sample]
    -- local collide_points = Physics:collide_objects(cube_obj, caps_obj)
    -- if #collide_points then 
    --     local function print_collide_points(points)
    --         for _, pt in ipairs(points) do
    --             print("point AInWorld:", 	pt.ptA_in_WS[1], 	pt.ptA_in_WS[2], 	pt.ptA_in_WS[3])
    --             print("point BInWorld:", 	pt.ptB_in_WS[1],	pt.ptB_in_WS[2],	pt.ptB_in_WS[3])
    --             print("normal BInWorld:", pt.normalB_in_WS[1],pt.normalB_in_WS[2],pt.normalB_in_WS[3])
    --             print("         distance:", 			pt.distance)        		
    --         end
    --     end
    --    -- print_collide_points(collide_points)
    -- end 
   

    --[raycast]
    -- local camera = world:first_entity("main_queue")
    -- local pos = self.math_stack(camera.position,"T")
    -- print_r("camera pos", pos[1],pos[2],pos[3] )

    -- local ray_s = { pos[1],1000, pos[3]}  -- { 100.5, 1000, 100.5 }
    -- local ray_e = { pos[1],-1000,pos[3]}  -- { 100.5, -1000, 100.5 }
    -- hit, result = Physics:raycast(ray_s, ray_e)
    -- if  hit  then 
    --     pos[2] = result.hit_pt_in_WS[2] + 4
    --     self.math_stack(camera.position,pos,'=')
    -- end 

end




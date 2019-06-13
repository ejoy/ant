local math3d = import_package "ant.math"
local ms = math3d.stack
local fs = require "filesystem"

local pbr_scene = {}


local function create_pbr_entity(world,name,pos,rot,scl,mesh_desc,material_desc,metal,rough)
    local eid = world:create_entity {
        name = name,
        transform = { s = scl, r = rot, t = pos,},
        can_render = true,
        can_select = true,
        material = { 
            content = {  {
                    ref_path =  fs.path ( material_desc ),
                }
            }
        },
        mesh = {
             ref_path = fs.path ( mesh_desc ),
        },
        main_view = true
    }

    local entity = world[eid]    

    if metal and rough then
        entity.material.content[1].properties.uniforms["u_params"].value = {0,0,metal,rough}
    end 
end 

local function to_radian(angles)
    local function radian(angle)
        return (math.pi / 180) * angle
    end

    local radians = {}
    for i=1, #angles do
        radians[i] = radian(angles[i])
    end
    return radians
end

function pbr_scene.create_scene(world)
    create_pbr_entity( world, "cerbernus",
                       {0,0,0,1},
                       {0,0,0},
                       {0.1,0.1,0.1},
                      "/pkg/ant.resources/sphere.mesh",
                      "//pbr/assets/material/Cerberus_LP.material"
                    )
    local rotation = to_radian({-90,90,0})
    create_pbr_entity( world, "cerbernus_gun",
                        {-12, 15, 14},
                        rotation,
                        {0.3,0.3,0.3},
                       "//pbr/assets/mesh_desc/Cerberus_LP.mesh",
                       "//pbr/assets/material/Cerberus_LP.material"
                 )

    for i = 0, 4 do 
        for j = 0, 4 do                                 
                local metal = 1
                local rough = (i*5+j)/25.0  
                create_pbr_entity(  world, "gold", 
                                {12.0+j*6, 7.7867187, -4.0 -i*6},
                                {0,0,0},
                                {0.05,0.05,0.05},
                                "/pkg/ant.resources/sphere.mesh",
                                "//pbr/assets/material/gold.material",
                                metal, rough )
        end 
    end   
    
    for i = 0, 4 do 
        for j = 0, 4 do                                 
                local metal = 0.0
                local rough = (i*5+j)/25.0  
                create_pbr_entity(  world, "plastic", 
                                {50.0+j*6, 7.7867187, -4.0 -i*6},
                                {0,0,0},
                                {0.05,0.05,0.05},
                                "/pkg/ant.resources/sphere.mesh",
                                "//pbr/assets/material/plastic.material",
                                metal, rough )
        end 
    end     

end 

return pbr_scene 

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local fs = require "filesystem"

local pbr_scene = {}

local function create_pbr_entity(world,name,pos,rot,scl,mesh_desc,material_desc,metal,rough)
    return world:create_entity {
        name = name,
        transform = { s = scl, r = rot, t = pos,},
        can_render = true,
        can_select = true,
        material = computil.assign_material(
            fs.path (material_desc),
            {
                uniforms = {
                    u_params = {type="v4", name="parameters", value={0,0,metal,rough}},
                }
            }
        ),
        rendermesh = {},
        mesh = {
             ref_path = fs.path ( mesh_desc ),
        },
        main_view = true
    }
end

function pbr_scene.create_scene(world)
    create_pbr_entity( world, "cerbernus",
                       {0,0,0,1},
                       {0,0,0},
                       {0.1,0.1,0.1},
                      "/pkg/ant.resources/sphere.mesh",
                      "//pbr/assets/material/Cerberus_LP.material"
                    )
    
    create_pbr_entity( world, "cerbernus_gun",
                        {-12, 15, 14},
                        mu.to_radian {-90,90,0},
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

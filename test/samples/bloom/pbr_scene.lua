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
                    u_params = {type="v4", name="u_params", value={0,0,metal,rough}},
                }
            }
        ),
        rendermesh = {},
        mesh = {
             ref_path = fs.path ( mesh_desc ),
        },
    }
end

function pbr_scene.create_scene(world)
    create_pbr_entity( world, "sphere",
                       {0,0,40,1},
                       {0,0,0},
                       {12,12,12},
                      "/pkg/bloom/assets/mesh/sphere.mesh",
                      "/pkg/bloom/assets/material/matrix_emiss.material",
                      0,0.7
                    )

    create_pbr_entity( world, "sphere",
                    {-40,0,40,1},
                    {0,0,0},
                    {12,12,12},
                   "/pkg/bloom/assets/mesh/sphere.mesh",
                   "/pkg/bloom/assets/material/brick1.material",
                   0,0.7
                 )


    create_pbr_entity( world, "cube",
                    {0,0,-40,1},
                    {0,0,0},
                    {12,12,12},
                   "/pkg/bloom/assets/mesh/cube.mesh",
                   "/pkg/bloom/assets/material/matrix.material",
                   0,0.7
                 )

    create_pbr_entity( world, "wooddoor",
                 {0-5,10,-40.5,1},
                 {0,0,0},
                 {12,1,1},
                "/pkg/bloom/assets/mesh/cube.mesh",
                "/pkg/bloom/assets/material/matrix.material",
                0,0.7
              )

    create_pbr_entity( world, "wooddoor",
              {5-5,5,-40,1},
              {0,0,0},
              {1,12,1},
             "/pkg/bloom/assets/mesh/cube.mesh",
             "/pkg/bloom/assets/material/matrix.material",
             0,0.7
           )
    create_pbr_entity( world, "wooddoor",
           {-5-5,5,-40,1},
           {0,0,0},
           {1,12,1},
          "/pkg/bloom/assets/mesh/cube.mesh",
          "/pkg/bloom/assets/material/matrix.material",
          0,0.7
        )



    create_pbr_entity( world, "floor",
                 {0,-10,0,1},
                 {0,0,0},
                 {180,1,180},
                "/pkg/bloom/assets/mesh/cube.mesh",
                "/pkg/bloom/assets/material/brick.material",
                0,1
              )

    create_pbr_entity( world, "wall_r",
              {80,-10,0,1},
              {0,0,0},
              {1,180,180},
             "/pkg/bloom/assets/mesh/cube.mesh",
             "/pkg/bloom/assets/material/stone_wall.material",
             0,1
           )
    create_pbr_entity( world, "wall_l",
           {-80,-10,0,1},
           {0,0,0},
           {1,180,180},
          "/pkg/bloom/assets/mesh/cube.mesh",
          "/pkg/bloom/assets/material/brick.material",
          0,1
        )


    local space = 8
    for item = 1, 1 do 
    for i = 0, 4 do 
        for j = 0, 4 do                                 
                local metal = 1
                local rough = (i*5+j)/25.0  
                create_pbr_entity(  world, "metal", 
                                {30.0+j*space, 7.7867187, 12.0-i*space},
                                {0,0,0},
                                {3.,3.,3.},
                                "/pkg/bloom/assets/mesh/sphere.mesh",
                                "/pkg/bloom/assets/material/Cerberus_LP.material",
                                metal, rough )
        end 
    end   


    for i = 0, 4 do 
        for j = 0, 4 do                                 
                local metal = 1
                local rough = (i*5+j)/25.0  
                create_pbr_entity(  world, "gold", 
                                {-22.0+j*space, 7.7867187, 12.0-i*space},
                                {0,0,0},
                                {3.,3.,3.},
                                "/pkg/bloom/assets/mesh/sphere.mesh",
                                "/pkg/bloom/assets/material/gold.material",
                                metal, rough )
        end 
    end   
    
   
    for i = 0, 4 do 
        for j = 0, 4 do                                 
                local metal = 0.0
                local rough = (i*5+j)/25.0  
                create_pbr_entity(  world, "plastic", 
                                {-70.0+j*space, 7.7867187, 12.0 -i*space},
                                {0,0,0},
                                {3.,3.,3.},
                                "/pkg/bloom/assets/mesh/sphere.mesh",
                                "/pkg/bloom/assets/material/plastic.material",
                                metal, rough )
        end 
    end     
    end

end 

return pbr_scene 

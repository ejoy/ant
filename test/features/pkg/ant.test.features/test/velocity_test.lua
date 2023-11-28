local ecs   = ...
local world = ecs.world
local w     = world.w

local vt_sys = ecs.system "velocity_test_system"

function vt_sys.init_world()
    world:create_entity {
        policy = {
            "ant.render|render",
         },
        data = {
            scene  = {s = 1, t = {0, 1, 0}},
            --material    = "/pkg/ant.resources.binary/meshes/base/cube.glb|materials/Material.001_nup.material",
            --material    = "/pkg/ant.resources.binary/meshes/wind-turbine-1.glb|materials/Material.001_skin.material",
            --material    = "/pkg/ant.resources/materials/pbr_stencil.material", 
            --material    = "/pkg/ant.resources.binary/meshes/Duck.glb|materials/blinn3-fx.material", 
            material    = "/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|materials/Material_MR.material", 
            --material    = "/pkg/ant.resources.binary/meshes/chimney-1.glb|materials/Material_skin_clr.material",
            --material    = "/pkg/ant.resources.binary/meshes/furnace-1.glb|materials/Material_skin.material",
            visible_state = "main_view|velocity_queue",
            --mesh        = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/Cube_P1.meshbin",
            --mesh        = "/pkg/ant.resources.binary/meshes/wind-turbine-1.glb|meshes/Plane.003_P1.meshbin",
            --mesh        = "/pkg/ant.resources.binary/meshes/Duck.glb|meshes/LOD3spShape_P1.meshbin",
            mesh        = "/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|meshes/mesh_helmet_LP_13930damagedHelmet_P1.meshbin",
            --mesh        = "/pkg/ant.resources.binary/meshes/chimney-1.glb|meshes/Plane_P1.meshbin",
            --mesh        = "/pkg/ant.resources.binary/meshes/furnace-1.glb|meshes/Cylinder.001_P1.meshbin",

        },
    }
end
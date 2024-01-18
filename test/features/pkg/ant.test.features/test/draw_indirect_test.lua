local ecs   = ...
local world = ecs.world
local w     = world.w

local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()

local dit_sys = common.test_system "draw_indirect"

function dit_sys.init_world()
--[[     sm_id = PC:create_entity {
        policy = {
            "ant.render|render",
        },
        data = {
            mesh = "/pkg/ant.test.features/mountain1.glb|meshes/Cylinder.002_P1.meshbin",
            scene = {s = {0.125, 0.125, 0.125}, t = {5, 0, 5}},
            material = "/pkg/ant.test.features/mountain1.glb|materials/Material_cnup.material",
            --material = "/pkg/ant.test.features/assets/pbr_test.material",
            visible_state = "main_view",
        }
    } ]]
--[[     PC:create_entity {
        policy = {
            "ant.render|render",
        },
        data = {
            mesh = "/pkg/ant.test.features/assets/t1.glb|meshes/zhuti.025_P1.meshbin",
            scene = {},
            material = "/pkg/ant.test.features/assets/t1.glb|materials/Material.material",
            visible_state = "main_view",
        }
    }
    PC:create_entity {
        policy = {
            "ant.render|render",
        },
        data = {
            mesh = "/pkg/ant.test.features/assets/cube.glb|meshes/Cube_P1.meshbin",
            scene = {t = {-5, 5, 0}},
            material = "/pkg/ant.test.features/assets/cube.glb|materials/Material.001.material",
            visible_state = "main_view",
        }
    } ]]
end

function dit_sys:exit()
    PC:clear()
end
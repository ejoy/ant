local ecs = ...
local world = ecs.world
local w = world.w

local common= ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()

local viewrect2d_test_sys = common.test_system "viewrect2d"

function viewrect2d_test_sys:init()
    PC:create_instance {
        prefab = "/pkg/ant.test.features/assets/entities/viewrect2d.prefab",
    }

    PC:create_entity {
        policy = {
            "ant.render|render2d",
        },
        data = {
            scene = {t={250, 250, 0}},
            material = "/pkg/ant.resources/materials/default2d.material",
            texturequad = "/pkg/ant.test.features/assets/textures/test_quad.texture",
            render_layer = "translucent",
            visible_state = "main_view",
        }
    }
end

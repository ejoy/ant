local ecs = ...
local world = ecs.world
local w = world.w

local common= ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()
local id2d = ecs.require "ant.render|2d.dynamic2d"
local viewrect2d_test_sys = common.test_system "viewrect2d"

local eid = 1
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
            visible     = true,
        }
    }
 
    eid = PC:create_entity {
        policy = {
            "ant.render|dynamic2d",
        },
        data = {
            scene = {t={700, 255, 0}},
            material = "/pkg/ant.resources/materials/default2d.material",
            dynamicquad = {
                texture = "/pkg/ant.test.features/assets/textures/test_dynamic_quad.texture",
                --texture = "/pkg/ant.resources/textures/atlas/t1.atlas",
                width = 320,
                height = 320,
                clear = {255, 255, 255, 255}    --initial clear color, default 0,0,0,0
            },
            render_layer = "translucent",
            visible     = true,
        }
    }

end

local key_mb = world:sub {"keyboard"}
function viewrect2d_test_sys:data_changed()
    for _, key, press in key_mb:unpack() do
        if key == "A" and press == 0 then
            id2d.update_pixels(eid,
                {
                    {pos = {x=16, y=16}, value = {255, 0, 0, 255}},
                    {pos = {x=1, y=1}, value = {255, 0, 0, 255}},
                    {pos = {x=1, y=32}, value = {255, 0, 0, 255}},
                    {pos = {x=32, y=1}, value = {255, 0, 0, 255}},
                    {pos = {x=32, y=32}, value = {255, 0, 0, 255}}
                }
            )
        end
    end

end
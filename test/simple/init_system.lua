local ecs = ...
local world = ecs.world
local m = ecs.system 'init_system'
local irq = world:interface "ant.render|irenderqueue"

function m:init_world()
    irq.set_view_clear_color("main_queue", 0)

    world:instance "res/scenes.prefab"
    world:instance "res/female.prefab"

    local object; do
        object = world:create_instance "res/camera.prefab"
        local camera = object.tag.camera[1]
        function object:on_init()
            world:call(camera, "get_postion")
        end
        function object:on_message(msg)
            print(object, msg)
        end
        function object:on_update()
            --print "update"
        end
    end
    local camera = world:create_object(object)
    camera:send "hello"
end

local ecs = ...
local world = ecs.world
local m = ecs.system 'init_system'
local irq = world:interface "ant.render|irenderqueue"

function m:init_world()
    irq.set_view_clear_color("main_queue", 0)

    world:instance "res/scenes.prefab"
    world:instance "res/female.prefab"
    --world:instance "res/camera.prefab"
    local object = world:create_object {
        "res/camera.prefab",
        init = function(object)
            print(object)
        end,
        message = function (object, msg)
            print(object, msg)
        end,
        update = function (o)
            --print "update"
        end,
    }
    object:message "hello"
end

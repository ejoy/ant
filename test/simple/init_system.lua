local ecs = ...
local world = ecs.world
local m = ecs.system 'init_system'
local irq = world:interface "ant.render|irenderqueue"

function m:init_world()
    irq.set_view_clear_color("main_queue", 0)
    world:instance "res/scenes.prefab"
    world:instance "res/female.prefab"
    local camera = ecs.require "camera"
    world:call(camera.root, "set_position", {1, 1, 1})
    camera:send "hello"
end

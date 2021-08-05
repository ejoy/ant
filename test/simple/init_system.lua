local ecs = ...
local world = ecs.world
local m = ecs.system 'init_system'
local irq = world:interface "ant.render|irenderqueue"

function m:init_world()
    irq.set_view_clear_color("main_queue", 0)

    world:instance "res/scenes.prefab"
    world:instance "res/camera.prefab"
    world:instance "res/female.prefab"
    --world:instance "res/fox.glb|mesh.prefab"
end

local ecs = ...
local world = ecs.world
local m = ecs.system 'init_system'
local irq = world:interface "ant.render|irenderqueue"
function m:init()
    irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0xa0a0a0ff)
    world:instance "res/scenes.prefab"
end

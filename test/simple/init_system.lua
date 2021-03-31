local ecs = ...
local world = ecs.world
local m = ecs.system 'init_system'
local irq = world:interface "ant.render|irenderqueue"
function m:init()
    irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0)

    world:prefab_instance "res/scenes.prefab"
    local prefab = world:prefab_instance "res/Fox.glb|mesh.prefab"
    world:prefab_event(prefab, "birth")
end

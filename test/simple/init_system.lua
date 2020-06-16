local ecs = ...
local world = ecs.world
local camera = world:interface "ant.render|camera"
local m = ecs.system 'init_system'

function m:init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
    local res = world:instance "res/camera.prefab"
    camera.bind(res[1], "main_queue")
    world:instance "res/procedural_sky.prefab"
    world:instance "res/plane.prefab"
    world:instance "res/light_directional.prefab"
    world:instance "res/fox.glb|mesh.prefab"
end

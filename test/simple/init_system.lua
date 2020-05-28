local ecs = ...
local world = ecs.world
local camera = world:interface "ant.render|camera"
local m = ecs.system 'init_system'

function m:init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
    camera.bind(camera.create { eyepos = {2, 1,-2, 1}, viewdir = {-2,-1,2,0} }, "main_queue")
    world:instance "res/light_directional.prefab"
    world:instance "res/box.glb|mesh.prefab"
end

local ecs = ...
local world = ecs.world
local camera = world:interface "ant.camera|camera"
local m = ecs.system 'init_system'

function m:init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
    local res = world:instance "res/scenes.prefab"
    camera.bind(res.camera, "main_queue")
end

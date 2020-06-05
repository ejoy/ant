local ecs = ...
local world = ecs.world
local camera = world:interface "ant.render|camera"
local render  = import_package 'ant.render'
local m = ecs.system 'init_system'

function m:init()
    render.components.create_procedural_sky(world)
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
    camera.bind(camera.create {
        eyepos = {-200, 100,200, 1},
        viewdir = {2,-1,-2,0},
        frustum = {f = 1000}
    }, "main_queue")
    world:instance "res/plane.prefab"
    world:instance "res/light_directional.prefab"
    local res = world:instance "res/fox.glb|mesh.prefab"
    world:add_policy(res[3], {
        policy = {"ant.render|shadow_cast_policy"},
        data = {can_cast = true},
    })
end

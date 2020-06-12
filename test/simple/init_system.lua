local ecs = ...
local world = ecs.world
local camera = world:interface "ant.render|camera"
local entity = world:interface "ant.render|entity"
local m = ecs.system 'init_system'

function m:init()
    entity.create_procedural_sky()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
    camera.bind(camera.create {
        eyepos = {-200, 100,200, 1},
        viewdir = {2,-1,-2,0},
        frustum = {f = 1000}
    }, "main_queue")
    --world:instance "res/plane.prefab"
    entity.create_plane_entity(
		{t = {0, 0, 0, 1}, s = {500, 1, 500, 0}},
		"/pkg/ant.resources/materials/mesh_shadow.material",
		{0.8, 0.8, 0.8, 1},
		"test shadow plane"
	)
    world:instance "res/light_directional.prefab"
    local res = world:instance "res/fox.glb|mesh.prefab"
    local ies = world:interface "ant.scene|ientity_state"
    local e = world[res[3]]
    e.state = e.state | ies.create_state "cast_shadow"
end

local ecs = ...
local world = ecs.world
local camera = world:interface "ant.render|camera"
local m = ecs.system 'init_system'

function m:init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
    camera.bind(camera.create {
        eyepos = {-200, 100,200, 1},
        viewdir = {2,-1,-2,0},
        frustum = {f = 1000}
    }, "main_queue")
    --world:instance "res/plane.prefab"
    local cu = import_package "ant.render".components
    cu.create_plane_entity(
		world,
		{srt = {t = {0, 0, 0, 1}, s = {50, 1, 50, 0}}},
		"/pkg/ant.resources/materials/mesh_shadow.material",
		{0.8, 0.8, 0.8, 1},
		"test shadow plane"
	)
    world:instance "res/light_directional.prefab"
    local res = world:instance "res/fox.glb|mesh.prefab"
    world:add_policy(res[3], {
        policy = {"ant.render|shadow_cast_policy"},
        data = {can_cast = true},
    })
end

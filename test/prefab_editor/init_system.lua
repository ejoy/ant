local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local iom = world:interface "ant.objcontroller|obj_motion"
local camera = world:interface "ant.camera|camera"
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
    -- local cu = import_package "ant.render".components
    -- entity.create_plane_entity(
	-- 	{srt = {t = {0, 0, 0, 1}, s = {50, 1, 50, 0}}},
	-- 	"/pkg/ant.resources/materials/mesh_shadow.material",
	-- 	{0.8, 0.8, 0.8, 1},
	-- 	"test shadow plane"
    -- )
    entity.create_grid_entity("", nil, nil, nil, {srt={r = {0,0.92388,0,0.382683},}})
	--local axis = entity.create_axis_entity()
    --world:instance '/pkg/tools.viewer.prefab_viewer/light_directional.prefab'
    world:instance "res/light_directional.prefab"
	-- local res = world:instance "res/fox.glb|mesh.prefab"
	-- world[res[3]].transform =  {s={0.01}}
    -- world:add_policy(res[3], {
    --     policy = {
	-- 		"ant.objcontroller|select"
	-- 	},
    --     data = {
	-- 		can_select = true,
	-- 		name = "fox",
	-- 	},
    -- })

    -- local cubeid = world:create_entity {
	-- 	policy = {
	-- 		"ant.render|render",
	-- 		"ant.general|name",
	-- 		"ant.objcontroller|select",
	-- 	},
	-- 	data = {
	-- 		scene_entity = true,
	--		state = ies.create_state "visible|selectable",
	-- 		transform =  {
	-- 			s=100,
	-- 			t={0, 2, 0, 0}
	-- 		},
	-- 		material = "/pkg/ant.resources/materials/singlecolor.material",
	-- 		mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
	-- 		name = "test_cube",
	-- 	}
	-- }
	--imaterial.set_property(cubeid, "u_color", {1, 1, 1, 1})
end

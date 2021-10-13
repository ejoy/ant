local ecs = ...
local math3d    = require "math3d"

local ientity = ecs.import.interface "ant.render|entity"
local imesh = ecs.import.interface "ant.asset|imesh"

local char_ik_test_sys = ecs.system "character_ik_test_system"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local function foot_ik_test()
    --return ecs.create_instance((entitydir / "character_ik_test.prefab"):string())
end

local function create_plane_test()
    ecs.create_entity{
		policy = {
            "ant.collision|collider_policy",
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			reference 	= true,
			scene 		= {
                srt =        {
                    s = {5, 1, 5, 0},
                    r = math3d.tovalue(math3d.quaternion{math.rad(10), 0, 0}),
                    t = {0, 0, -5, 1},
                }
            },
			material 	= "/pkg/ant.resources/materials/test/singlecolor_tri_strip.material",
			state 		= "visible",
			name 		= "test shadow plane",
			simplemesh 	= imesh.init_mesh(ientity.plane_mesh()),
            collider = {
                box = {{
                    origin = {0, 0, 0, 1},
                    size = {5, 0.001, 5},
                }}
            },
            debug_mesh_bounding = true,
			on_ready = function (e)
				imaterial.set_property(e, "u_color", {0.5, 0.5, 0, 1})
			end,
		}
    }
end

function char_ik_test_sys:init()
    create_plane_test()
    foot_ik_test()
end
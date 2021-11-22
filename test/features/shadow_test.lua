local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local ientity 	= ecs.import.interface "ant.render|entity"
local imesh		= ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local st_sys	= ecs.system "shadow_test_system"
function st_sys:init()
	ecs.create_entity {
		policy = {
			"ant.render|render",
			"ant.scene|scene_object",
			"ant.general|name",
		},
		data = {
			filter_state = "visible|selectable|cast_shadow",
			scene =  {
				srt = {
					s=100,
					t={0, 2, 0, 0}
				}
			},
			material = "/pkg/ant.resources/materials/singlecolor.material",
			mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
			name = "cast_shadow_cube",
		}
	}

	ecs.create_entity {
		policy = {
			"ant.scene|scene_object",
			"ant.general|name",
		},
		data = {
			scene =  {
				srt = {
					t = {0, 0, 3, 1}
			}},
			name = "mesh_root",
		}
	}
	ecs.create_instance "/pkg/ant.resources.binary/meshes/RiggedFigure.glb|mesh.prefab"

	ecs.create_entity{
		policy = {
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			scene 		= {
                srt = {
                    t = {0, 0, 0, 1}, s = {50, 1, 50, 0}
                }
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			filter_state= "main_view",
			name 		= "test_shadow_plane",
			simplemesh 	= imesh.init_mesh(ientity.plane_mesh()),
            debug_mesh_bounding = true,
			on_ready = function (e)
				imaterial.set_property(e, "u_basecolor_factor", {0.8, 0.8, 0.8, 1})
			end,
		}
    }
end

function st_sys:post_init()
	--ilight.create_light_direction_arrow(ilight.directional_light(), {scale=0.02, cylinder_cone_ratio=1, cylinder_rawradius=0.45})
end

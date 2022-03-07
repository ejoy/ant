local ecs	= ...
local world = ecs.world
local w 	= world.w
local math3d = require "math3d"

local ientity 	= ecs.import.interface "ant.render|ientity"
local imesh		= ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local st_sys	= ecs.system "shadow_test_system"
function st_sys:init()
	ecs.create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
		},
		data = {
			filter_state = "main_view|selectable|cast_shadow",
			scene =  {
				srt = {
					s=100,
					t={3, 1, 0, 0}
				}
			},
			material = "/pkg/ant.resources/materials/singlecolor.material",
			mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
			name = "cast_shadow_cube",
		}
	}

	local root = ecs.create_entity {
		policy = {
			"ant.scene|scene_object",
			"ant.general|name",
		},
		data = {
			scene =  {
				srt = {
					t = {0, 0, 0, 1}
			}},
			name = "mesh_root",
		}
	}
	ecs.create_instance "/pkg/ant.resources.binary/meshes/RiggedFigure.glb|mesh.prefab"

	local ee = ecs.create_entity{
		policy = {
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			scene 		= {
                srt = {
                    t = {0, 0, 0, 1}, s = {50, 1, 50, 0}
                },
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
	ecs.method.set_parent(ee, root)
end

function st_sys:entity_init()
	for e in w:select "INIT make_shadow light:in scene:in id:in" do
		local ee = ientity.create_arrow_entity({}, 0.3, {1000, 1000, 1000, 1}, "/pkg/ant.resources/materials/meshcolor.material")
		ecs.method.set_parent(ee, e.id)
	end
end

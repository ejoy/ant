local ecs	= ...
local world = ecs.world
local w 	= world.w
local math3d = require "math3d"

local ientity 	= ecs.import.interface "ant.render|ientity"
local imesh		= ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local iom		= ecs.import.interface "ant.objcontroller|iobj_motion"

local st_sys	= ecs.system "shadow_test_system"
function st_sys:init()
	local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/base/cube.glb|mesh.prefab"
	p.on_ready = function (e)
		--iom.set_position(world:entity(e.root), math3d.vector(3, 1, 0))
	end
	world:create_object(p)

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
	--ecs.create_instance "/pkg/ant.resources.binary/meshes/RiggedFigure.glb|mesh.prefab"

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
				w:sync("render_object:update", e)
				imaterial.set_property(e, "u_basecolor_factor", math3d.vector(0.8, 0.8, 0.8, 1))
			end,
		}
    }
	ecs.method.set_parent(ee, root)
end

function st_sys:entity_init()
	for e in w:select "INIT make_shadow light:in scene:in id:in" do
		local ee = ientity.create_arrow_entity({}, 0.3, {1, 1, 1, 1}, "/pkg/ant.resources/materials/meshcolor.material")
		ecs.method.set_parent(ee, e.id)
	end
end

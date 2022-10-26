local ecs	= ...
local world = ecs.world
local w 	= world.w
local math3d = require "math3d"

local ientity 	= ecs.import.interface "ant.render|ientity"
local imesh		= ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local iom		= ecs.import.interface "ant.objcontroller|iobj_motion"

local function create_instance(pfile, s, r, t)
	s = s or {0.1, 0.1, 0.1}
	local p = ecs.create_instance(pfile)
	p.on_ready = function (e)
		local ee<close> = w:entity(e.tag["*"][1])
		iom.set_scale(ee, s)

		if r then
			iom.set_rotation(ee, r)
		end

		if t then
			iom.set_position(ee, t)
		end
	end
	world:create_object(p)
end

local st_sys	= ecs.system "shadow_test_system"
function st_sys:init()
	create_instance("/pkg/ant.resources.binary/meshes/base/cube.glb|mesh.prefab", {10, 0.1, 10}, nil, {10, 0, 0, 1})
	local root = ecs.create_entity {
		policy = {
			"ant.scene|scene_object",
			"ant.general|name",
		},
		data = {
			scene =  {t={10, 0, 0}},
			name = "mesh_root",
		}
	}

	create_instance "/pkg/ant.resources.binary/meshes/RiggedFigure.glb|mesh.prefab"

	ecs.create_entity{
		policy = {
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			scene 		= {
                srt = {
                    t = {0, 0, 0, 1}, s = {50, 1, 50, 0}
                },
				parent = root,
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			visible_state= "main_view",
			name 		= "test_shadow_plane",
			simplemesh 	= imesh.init_mesh(ientity.plane_mesh()),
            debug_mesh_bounding = true,
			on_ready = function (e)
				imaterial.set_property(e, "u_basecolor_factor", math3d.vector(0.8, 0.8, 0.8, 1))
			end,
		}
    }
end

function st_sys:entity_init()
	for e in w:select "INIT make_shadow light:in scene:in eid:in" do
		ientity.create_arrow_entity(0.3, {1, 1, 1, 1}, "/pkg/ant.resources/materials/meshcolor.material", {parent=e.eid})
	end
end

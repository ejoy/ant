local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system "init_system"

local ientity = ecs.require "ant.render|components.entity"
local iom = ecs.require "ant.objcontroller|obj_motion"
local imesh = ecs.require "ant.asset|mesh"
local imaterial = ecs.require "ant.asset|material"
local math3d = require "math3d"

function m:init_world()
	local mq = w:first "main_queue camera_ref:in"
	local ce <close> = world:entity(mq.camera_ref, "camera:in")
	local eyepos = math3d.vector(0, 100, -100)
	iom.set_position(ce, eyepos)
	local dir = math3d.normalize(math3d.sub(math3d.vector(0.0, 0.0, 0.0, 1.0), eyepos))
	iom.set_direction(ce, dir)

	world:create_entity {
		policy = {
			"ant.render|simplerender",
		},
		data = {
			scene = {
				t = {0, 0, 0, 1}, s = {500, 1, 500, 0}
			},
			material = "/pkg/ant.resources/materials/mesh_shadow.material",
			visible_state= "main_view",
			simplemesh = imesh.init_mesh(ientity.plane_mesh()),
			debug_mesh_bounding = true,
			on_ready = function (e)
				imaterial.set_property(e, "u_basecolor_factor", math3d.vector(0.8, 0.8, 0.8, 1))
			end,
		}
	}

	world:create_instance {
		prefab = "/pkg/ant.test.simple/resource/light.prefab"
	}
	world:create_instance {
		prefab = "/pkg/vaststars.resources/glbs/miner-1.glb|work.prefab",
	}
end

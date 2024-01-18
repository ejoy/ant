local ecs = ...
local world = ecs.world

local m = ecs.system "init_system"

local ientity = ecs.require "ant.render|components.entity"
local imesh = ecs.require "ant.asset|mesh"

function m:init_world()
	world:create_entity {
		policy = {
			"ant.render|simplerender",
		},
		data = {
			scene = {
				t = {0, 0, 0, 1},
				s = {500, 1, 500, 0}
			},
			material = "/pkg/ant.resources/materials/mesh_shadow.material",
			visible_state = "main_view",
			simplemesh = imesh.init_mesh(ientity.plane_mesh()),
		}
	}

	world:create_instance {
		prefab = "/pkg/ant.test.simple/resource/light.prefab"
	}
end

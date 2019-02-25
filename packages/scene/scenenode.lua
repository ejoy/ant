local ecs = ...
local world = ecs.world

ecs.component_alias("world_transform", "transform")

local testscene = ecs.system "test_scene"
function testscene:init()
	local root_eid = world:create_entity {
		world_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		can_render = true,
		name = "root",
	}

	local childeid = world:create_entity {
		world_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},			
		},
		transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		parent = {
			eid = root_eid,
		},
		can_render = true,
		name = "child1",
	}

	local chideid2 = world:create_entity {
		world_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		parent = {
			eid = root_eid,
		},
	}


end
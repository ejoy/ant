local ecs = ...
local world = ecs.world
local schema = world.schema
local fs = require "filesystem"

schema:typedef("world_transform", "transform")
	

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
		main_viewtag = true,
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
		main_viewtag = true,
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
		name = "child2",
		main_viewtag = true,
	}


end
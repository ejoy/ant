local ecs = ...
local world = ecs.world

local fs = require "filesystem"

ecs.tag "hierarchy_tag"

ecs.component_alias("world_transform", "transform")
ecs.component_alias("hierarchy_transform", "transform")
ecs.component_alias("base_transform", "transform")

ecs.component_alias("attach", "entityid")

local hierarchy_transform_result = ecs.singleton "hierarchy_transform_result"
function hierarchy_transform_result:init()

end

local testscene = ecs.system "test_scene"
testscene.singleton "modify"
testscene.singleton "hierarchy_transform_result"


function testscene:init()
	local material = {
		content = {
			{
				ref_path = {package="ant.resources", filename=fs.path "bunny.material"}
			}
		}
	}

	local hie_root = world:create_entity {				
		hierarchy_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},		
		name = "root",
		hierarchy_tag = true,
		main_viewtag = true,
	}

	local hie_level1_1 = world:create_entity {		
		hierarchy_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		parent = hie_root,
		name = "level1_1",
		hierarchy_tag = true,
		main_viewtag = true,
	}

	local hie_level1_2 = world:create_entity {		
		hierarchy_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		parent = hie_root,
		name = "level1_2",
		hierarchy_tag = true,
		main_viewtag = true,
	}

	local hie_level2_1 = world:create_entity {
		hierarchy_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		parent = hie_level1_2,
		name = "level2_1",
		hierarchy_tag = true,
		main_viewtag = true,
	}


	local render_root = world:create_entity {
		world_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		base_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},		
		attach = hie_root,
		name = "render_root",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "cube.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}

	local render_level1_1 = world:create_entity {
		world_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		base_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		parent = hie_root,
		attach = hie_level1_1,
		name = "render_level1",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "sphere.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}

	local render_level1_2 = world:create_entity {
		world_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		base_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		parent = hie_root,
		attach = hie_level1_2,
		name = "render_level1_2",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "sphere.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}


	local render_level2_1 = world:create_entity {
		world_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		base_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		parent = hie_level1_2,
		attach = hie_level2_1,
		name = "render_level2_eid1",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "sphere.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}

	--[[
				render_root		hie_root
								/		\
							   /		 \
							  /		 	  \
							 /		 	   \
render_level1_1			hie_level1_1	hie_level1_2		render_level1_2
							/			 	 \
						   /				  \
						  /					   \
						render_child1 		hie_level2_1	render_level2_1
												/
											   /
										render_child2_1
	]]

	local render_child1 = world:create_entity{
		world_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		base_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		parent = hie_level1_1,
		name = "render_child1",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "sphere.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}

	local render_child2_1 = world:create_entity{
		world_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		base_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		parent = hie_level2_1,
		name = "render_child2_1",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "sphere.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}

	self.modify:new(hie_root, "hierarchy_transform")
	self.modify:new(hie_level1_1, "hierarchy_transform")
	self.modify:new(hie_level1_2, "hierarchy_transform")
	self.modify:new(hie_level2_1, "hierarchy_transform")


	self.modify:new(render_root, "base_transform")
	self.modify:new(render_level1_1, "base_transform")
	self.modify:new(render_level1_2, "base_transform")
	self.modify:new(render_level2_1, "base_transform")
end


function testscene:event_changed()
	for eid, modify in self.modify:each("base_transform") do
		local e = world[eid]
		local attacheid = e.attach
		local attache = world[attacheid]
		e.base_transform = modify
		attache.hierarchy_transform = modify		
	end


	local hierarchy_result = self.hierarchy_transform_result


	local eids = {}
	local map = {}
	for eid, modify in self.modify:each("hierarchy_transform") do
		eids[eid] = {parent=world[eid].parent, modify=modify}		
	end

	local leafs = {}
	for eid, item in pairs(eids) do
		leafs[item.parent] = false
		leafs[eid] = true
	end

	for _, l in ipairs(leafs) do
		local e = world[l]
		print("leaf : ", l, e.name)
	end
end

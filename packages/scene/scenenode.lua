local ecs = ...
local world = ecs.world

local fs = require "filesystem"

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

ecs.tag "hierarchy_tag"

ecs.component_alias("world_transform", "transform")
ecs.component_alias("hierarchy_transform", "transform")
ecs.component_alias("base_transform", "transform")

ecs.component_alias("attach", "entityid")

local hierarchy_transform_result = ecs.singleton "hierarchy_transform_result"
function hierarchy_transform_result:init()

end

local testscene = ecs.system "test_scene"
testscene.singleton "event"
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
end

function testscene:post_init()
	for eid in world:each_new("hierarchy_transform") do
		self.event:new(eid, "hierarchy_transform")
	end

	for eid in world:each_new("base_transform") do
		self.event:new(eid, "base_transform")
	end
end

local scene_space_update = ecs.component "scene_space_update"
scene_space_update.singleton "event"

function scene_space_update:event_changed()
	for eid, modify in self.event:each("base_transform") do
		local e = world[eid]
		local attacheid = e.attach
		local attache = world[attacheid]
		e.base_transform = modify
		attache.hierarchy_transform = modify		
	end


	local hierarchy_result = self.hierarchy_transform_result

	local eids = {}	
	for eid, modify in self.event:each("hierarchy_transform") do
		local e = world[eid]
		e.hierarchy_transform = modify
		eids[#eids+1] = eid
	end

	if #eids > 0 then
		local function find_parent_eid(eid)
			for idx, peid in ipairs(eids) do
				if peid == eid then
					return idx
				end
			end
		end

		for _, eid in world:each "hierarchy_transform" do
			local e = world[eid]
			local idx = find_parent_eid(e.parent) 
			if idx then
				table.insert(eids, idx+1, eid)
			end
		end

		for _, eid in ipairs(eids) do
			local e = world[eid]
			local peid = e.parent 
			if peid then
				local parent = world[peid]
				local wt = parent.world_transform
				ms(e.world_transform, wt, e.world_transform, "*=")
				hierarchy_result[eid] = e.world_transform
			end
		end

	end

	
end

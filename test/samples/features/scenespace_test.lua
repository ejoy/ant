local ecs = ...
local world = ecs.world

local ms = import_package "ant.math".stack
local fs = require "filesystem"
local scenespace_test = ecs.system "scenespace_test"
scenespace_test.singleton 'event'
scenespace_test.singleton 'frame_stat'

scenespace_test.depend 'scene_space'
scenespace_test.depend 'init_loader'

local hie_refpath = fs.path '//ant.resources' / 'hierarchy' / 'test_hierarchy.hierarchy'
local function add_hierarchy_file(hiepath)
	local hierarchy_module = require 'hierarchy'
	local root = hierarchy_module.new()
	local s = ms({0.01, 0.01, 0.01}, "m")
	local h1_node = root:add_child('h1', s, nil, ms({3, 4, 5}, "m"))
	root:add_child('h2', s, nil, ms({1, 2, 3}, 'm'))
	h1_node:add_child('h1_h1', nil, nil, ms({0, 2, 0}, 'm'))

	local function save_rawdata(handle, respath)
		local realpath = respath:localpath()

		local localfs = require 'filesystem.local'
		localfs.create_directories(realpath:parent_path())

		handle:save(realpath:string())
	end

	local builddata = hierarchy_module.build(root)
	save_rawdata(builddata, hiepath)
end

local function create_scene_node_test()
    local material = {
        content = {
            {
                ref_path = fs.path '//ant.resources/bunny.material'
            }
        }
    }

    local hie_root =
        world:create_entity {
        hierarchy_transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
        name = 'root',
        hierarchy_tag = true,
        main_viewtag = true
    }

    local hie_level1_1 =
        world:create_entity {
        hierarchy_transform = {
			parent = hie_root,
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {2, 0, 0, 1},
		},
        name = 'level1_1',
        hierarchy_tag = true,
        main_viewtag = true
	}

    local hie_level1_2 =
        world:create_entity {
        hierarchy_transform = {
			parent = hie_root,
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {2, 0, 4, 1},
		},
        name = 'level1_2',
        hierarchy_tag = true,
        main_viewtag = true
	}
	
    local hie_level2_1 =
        world:create_entity {
        hierarchy_transform = {
			parent = hie_level1_2,
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {-2, 0, 0, 1},
			hierarchy = {
				ref_path = hie_refpath,
			}
		},
        name = 'level2_1',
        hierarchy_tag = true,
        main_viewtag = true
    }
    --[[
								hie_root
								/		\
							   /		 \
							  /		 	  \
							 /		 	   \
						hie_level1_1	hie_level1_2
							/			 	 \
						   /				  \
						  /					   \
						render_child1 		hie_level2_1
												/
											   /
										render_child2_1
	]]
    local render_child1_1 =
        world:create_entity {
        transform = {
			parent = hie_level1_1, 
			s = {0.01, 0.01, 0.01, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
        name = 'render_child1_1',
        mesh = {
            ref_path = fs.path '//ant.resources/sphere.mesh'
        },
        material = material,
        can_render = true,
        main_viewtag = true
	}
	
	
    local render_child1_2 =
        world:create_entity {
        transform = {
			parent = hie_level1_2, 
			s = {0.01, 0.01, 0.01, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
        name = 'render_child1_2',
        mesh = {
            ref_path = fs.path '//ant.resources/cylinder.mesh'
        },
        material = material,
        can_render = true,
        main_viewtag = true
    }

    local render_child2_1 =
        world:create_entity {
        transform = {
			parent = hie_level2_1, 
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
			slotname = "h1_h1",
		},
        name = 'render_child2_1',
        mesh = {
            ref_path = fs.path '//ant.resources/cube.mesh'
        },
        material = material,
        can_render = true,
        main_viewtag = true
	}
end

function scenespace_test:init()
	add_hierarchy_file(hie_refpath)
	create_scene_node_test()
end

local function find_entity_by_name(name, componenttype)
	for _, eid in world:each(componenttype) do
		local e = world[eid]
		if e.name == name then
			return eid
		end
	end
end

local onetime = nil
local function change_scene_node_test()
	if onetime == nil then
		local level1_2_eid = find_entity_by_name('level1_2', 'hierarchy_transform')
		if level1_2_eid then
			local level1_2 = world[level1_2_eid]
			local level1_2_trans = level1_2.hierarchy_transform
		
			local level1_1_eid = find_entity_by_name('level1_1', 'hierarchy_transform')

			local level1_1 = world[level1_1_eid]
			local level1_1_trans = level1_1.hierarchy_transform
			assert(level1_1_trans.parent == level1_2_trans.parent)

			level1_2_trans.watcher.parent = level1_1_eid
		end

		onetime = true
	end
end

local function print_scene_nodes()	
	local rooteids = {}
	local function find_node(tree, eid)
		for k, v in pairs(tree) do
			if k == eid then
				return v
			end
			local node = find_node(v, eid)
			if node then
				return node
			end
		end
	end

	local function add_node(tree, eid, transformtype)
		local node = find_node(tree, eid)
		if node then
			return node
		end
		local peid = world[eid][transformtype].parent
		node = {}
		if peid == nil then
			tree[eid] = node
		else
			local parent = add_node(tree, peid, transformtype)
			parent[eid] = node
		end

		return node
	end

	for _, eid in world:each "hierarchy_transform" do
		add_node(rooteids, eid, "hierarchy_transform")
	end

	for _, eid in world:each "transform" do
		add_node(rooteids, eid, "transform")
	end

	local function remove_no_child_tree(tree)
		local removeeids = {}
		for eid, subtr in pairs(tree) do
			if not next(subtr) then
				removeeids[#removeeids+1] = eid
			end
		end

		for _, eid in ipairs(removeeids) do
			tree[eid] = nil
		end
	end

	remove_no_child_tree(rooteids)

	local function print_tree(tree, depth)	
		for eid, children in pairs(tree)do
			local prefix = ''
			for i=1, depth - 1 do
				prefix = prefix .. '--'
			end			
			print(prefix .. "eid:", eid, "name:", world[eid].name)
			print_tree(children, depth+1)
		end
	end

	print_tree(rooteids, 1)
end

local whichframe
function scenespace_test:event_changed()
	change_scene_node_test()

	if whichframe == nil then
		print_scene_nodes()
		whichframe = self.frame_stat.frame_num
	elseif self.frame_stat.frame_num == whichframe + 1 then
		print_scene_nodes()
	elseif self.frame_stat.frame_num == whichframe + 2 then 
		local level1_1_eid = find_entity_by_name('level1_1', 'hierarchy_transform')
		world:remove_entity(level1_1_eid)
	elseif self.frame_stat.frame_num == whichframe + 3 then
		print_scene_nodes()
	end
end

function scenespace_test:post_init()

end

function scenespace_test:update()
	
end
local ecs = ...
local world = ecs.world

local mathpkg       = import_package "ant.math"
local ms            = mathpkg.stack
local mu            = mathpkg.util

local seriazlizeutil= import_package "ant.serialize"
local renderpkg     = import_package "ant.render"
local computil      = renderpkg.components

local fs            = require "filesystem"

local scenespace_test = ecs.system "scenespace_test"
scenespace_test.singleton 'event'
scenespace_test.singleton 'frame_stat'

scenespace_test.depend 'scene_space'
scenespace_test.depend 'init_loader'

local hie_refpath = fs.path '/pkg/ant.resources' / 'hierarchy' / 'test_hierarchy.hierarchy'
local function add_hierarchy_file(hiepath)
    local hierarchy_module = require 'hierarchy'
    local root = hierarchy_module.new()
    local s = ms({0.01, 0.01, 0.01}, "P")
    local h1_node = root:add_child('h1', s, nil, ms({3, 4, 5}, "P"))
    root:add_child('h2', s, nil, ms({1, 2, 3}, 'P'))
    h1_node:add_child('h1_h1', nil, nil, ms({0, 2, 0}, 'P'))

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
    local materialpath = fs.path '/pkg/ant.resources/materials/bunny.material'

    local hie_root =
        world:create_entity {
        hierarchy_visible = true,
        transform = mu.srt(),
        hierarchy = {},
        name = 'root',
        main_view = true,
        serialize = seriazlizeutil.create(),
    }

    local hie_level1_1 =
        world:create_entity {
        hierarchy_visible = true,
        transform = {
            parent = hie_root,
            s = {1, 1, 1, 0},
            r = {0, 0, 0, 0},
            t = {2, 0, 0, 1},
        },
        name = 'level1_1',
        hierarchy = {visible = true,},
        main_view = true,
        serialize = seriazlizeutil.create(),
    }

    local hie_level1_2 =
        world:create_entity {
        hierarchy_visible = true,
        transform = {
            parent = hie_root,
            s = {1, 1, 1, 0},
            r = {0, 0, 0, 0},
            t = {2, 0, 4, 1},
        },
        hierarchy = {
            visible = true,
        },
        name = 'level1_2',
        hierarchy_tag = true,
        main_view = true,
        serialize = seriazlizeutil.create(),
    }
    
    local hie_level2_1 =
        world:create_entity {
        hierarchy_visible = true,
        transform = {
            parent = hie_level1_2,
            s = {1, 1, 1, 0},
            r = {0, 0, 0, 0},
            t = {-2, 0, 0, 1},
        },
        hierarchy = {
            visible = true,
            ref_path = hie_refpath,
        },
        name = 'level2_1',
        main_view = true,
        serialize = seriazlizeutil.create(),
    }
    --[[
                                hie_root
                                /       \
                               /         \
                              /           \
                             /             \
                        hie_level1_1    hie_level1_2
                            /                \
                           /                  \
                          /                    \
                        render_child1       hie_level2_1
                                                /
                                               /
                                        render_child2_1
    ]]
    local render_child1_1 =
        world:create_entity {
        transform = {
            parent = hie_level1_1, 
            s = {100, 100, 100, 0},
            r = {0, 0, 0, 0},
            t = {0, 0, 0, 1},
        },
        name = 'render_child1_1',
        rendermesh = {},
        mesh = {
            ref_path = fs.path '/pkg/ant.resources/meshes/sphere.mesh'
        },
        material = computil.assign_material(materialpath),
        can_render = true,
        hierarchy_visible = true,
        can_select = true,
        main_view = true,
        serialize = seriazlizeutil.create(),
    }
    
    
    local render_child1_2 =
        world:create_entity {
        transform = {
            parent = hie_level1_2, 
            s = {100, 100, 100, 0},
            r = {0, 0, 0, 0},
            t = {0, 0, 0, 1},
        },
        name = 'render_child1_2',
        rendermesh = {},
        mesh = {
            ref_path = fs.path '/pkg/ant.resources/meshes/sphere.mesh'
        },
        material = computil.assign_material(materialpath),
        can_render = true,
        hierarchy_visible = true,
        can_select = true,
        main_view = true,
        serialize = seriazlizeutil.create(),
    }

    local render_child2_1 =
        world:create_entity {
        transform = {
            parent = hie_level2_1, 
            s = {100, 100, 100, 0},
            r = {0, 0, 0, 0},
            t = {0, 2, 0, 1},
            --slotname = "h1_h1",
        },
        name = 'render_child2_1',
        rendermesh = {},
        mesh = {
            ref_path = fs.path '/pkg/ant.resources/meshes/cube.mesh'
        },
        material = computil.assign_material(materialpath),
        can_render = true,
        hierarchy_visible = true,
        can_select = true,
        main_view = true,
        serialize = seriazlizeutil.create(),
    }

    --[[
                                hie_root2
                                /       \
                               /         \
                              /           \
                             /             \
                        hie2_level1_1   render2_rootchild
                            /
                           /
                          /
                    render2_child1
    ]]

    local hie_root2 =
        world:create_entity {
        transform = {
            s = {1, 1, 1, 0},
            r = {0, 0, 0, 0},
            t = {3, 0, -3, 1},
        },
        name = 'hie_root2',
        hierarchy = {},
        main_view = true,
        serialize = seriazlizeutil.create(),
        hierarchy_visible = true,
    }

    local hie2_level1_1 =
        world:create_entity {
        transform = {
            s = {1, 1, 1, 0},
            r = {0, 0, 0, 0},
            t = {0, 5, 0, 1},
            parent = hie_root2,
        },
        hierarchy = {},
        name = 'hie2_level1_1',
        main_view = true,
        serialize = seriazlizeutil.create(),
        hierarchy_visible = true,
    }

    local function color_material(colorvalue)
        return computil.assign_material(fs.path "/pkg/ant.resources/materials/simple_mesh.material",
                {
                    uniforms = {
                        u_color = {type="color", name = "color", value=colorvalue},
                    }
                })
    end

    local render2_rootchild =
        world:create_entity {
        transform = {
            parent = hie_root2, 
            s = {0.01, 0.01, 0.01, 0},
            r = {0, 0, 0, 0},
            t = {0, 0, -3, 1},
        },
        name = 'render2_rootchild',
        rendermesh = {},
        mesh = {
            ref_path = fs.path '/pkg/ant.resources/meshes/cube.mesh'
        },
        material = computil.assign_material(materialpath),
        can_render = true,
        hierarchy_visible = true,
        can_select = true,
        main_view = true,
        serialize = seriazlizeutil.create(),
    }

    local render2_child1 =
        world:create_entity {
        transform = {
            parent = hie2_level1_1, 
            s = {0.01, 0.01, 0.01, 0},
            r = {0, 0, 0, 0},
            t = {0, 0, 0, 1},
        },
        name = 'render2_child1',
        rendermesh = {},
        mesh = {
            ref_path = fs.path '/pkg/ant.resources/meshes/sphere.mesh'
        },
        material = computil.assign_material(materialpath),
        can_render = true,
        hierarchy_visible = true,
        can_select = true,
        main_view = true,
        serialize = seriazlizeutil.create(),
    }
end

function scenespace_test:init()
    --add_hierarchy_file(hie_refpath)
    assert(fs.exists(hie_refpath))
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
        local level1_2_eid = find_entity_by_name('level1_2', 'hierarchy')
        if level1_2_eid then
            local level1_2 = world[level1_2_eid]
            local level1_2_trans = level1_2.transform
        
            local level1_1_eid = find_entity_by_name('level1_1', 'hierarchy')

            local level1_1 = world[level1_1_eid]
            local level1_1_trans = level1_1.transform
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

    local function add_node(tree, eid)
        local node = find_node(tree, eid)
        if node then
            return node
        end
        local peid = world[eid].transform.parent
        node = {}
        if peid == nil then
            tree[eid] = node
        else
            local parent = add_node(tree, peid)
            parent[eid] = node
        end

        return node
    end

    for _, eid in world:each "hierarchy" do
        add_node(rooteids, eid)
    end

    for _, eid in world:each "can_render" do
        add_node(rooteids, eid)
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

local function print_tree()
    local hi = {}
    hi[0] = {}
    for i = 1,#world do
        local e = world[i]
        if e then
            local pid = e.parent
            if not pid and e.transform then
                pid = e.transform.parent
            end
            if pid then
                hi[pid] = hi[pid] or {}
                table.insert(hi[pid],i)
            else
                table.insert(hi[0],i)
            end
        end
    end
    do
        local function bfs(id,tab)
            if hi[id] then
                local next_tab = tab.."    "
                
                for _,v in ipairs(hi[id]) do
                    local o = ""
                    o = o .. next_tab..v..":"..(world[v].name or "nil")
                    if world[v].transform then
                        if world[v].hierarchy then
                            o = o .. "transform[hierarchy]"
                        else
                            o = o .. " transform"
                        end
                    end
                    print(o)
                    bfs(v,next_tab)
                end
            end
        end
        print("tree_begin")
        bfs(0,"")
        print("tree_end")

    end
end


local function move_root_node(rootnodename)
    local eid = find_entity_by_name(rootnodename, 'hierarchy')
    local e = world[eid]
    e.transform.watcher.t = {10, 0, 0, 1}
end

local whichframe
function scenespace_test:event_changed()
    change_scene_node_test()

    if whichframe == nil then
        print_scene_nodes()
        print_tree()
        whichframe = self.frame_stat.frame_num
    elseif self.frame_stat.frame_num == whichframe + 1 then
        print_scene_nodes()
        print_tree()
    elseif self.frame_stat.frame_num == whichframe + 2 then 
        local level1_1_eid = find_entity_by_name('level1_1', 'transform')
        world:remove_entity(level1_1_eid)
    elseif self.frame_stat.frame_num == whichframe + 3 then
        print_scene_nodes()
        print_tree()
    elseif self.frame_stat.frame_num == whichframe + 4 then
        move_root_node('hie_root2')
    end
end

function scenespace_test:post_init()

end

function scenespace_test:update()
    
end
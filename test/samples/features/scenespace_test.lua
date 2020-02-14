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
scenespace_test.require_singleton 'frame_stat'

scenespace_test.require_system 'ant.scene|scene_space'

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
    local materialpath = fs.path '/pkg/ant.resources/depiction/materials/bunny.material'

    local default_hie_policy = {
        "ant.scene|hierarchy",
        "ant.render|name",
        "ant.serialize|serialize"
    }

    --[[
                                 hie_root
                                /        \
                               /          \
                              /            \
                             /              \
                        hie_level1_1    hie_level1_2
                            /                /  \
                           /                /    \
                          /                /      \
                render_child1_1 render_child1_2 hie_level2_1
                                                   /
                                                  /
                                           render_child2_1
    ]]

    local hie_root =
        world:create_entity {
            policy = default_hie_policy,
            data = {
                hierarchy = {},
                hierarchy_visible = true,
                transform = mu.translate_mat {0, 5, 0, 1},
                name = 'hie_root',
                serialize = seriazlizeutil.create(),
            }
        }

    local hie_level1_1 =
        world:create_entity {
            policy = default_hie_policy,
            data = {
                hierarchy_visible = true,
                transform = {
                    parent = hie_root,
                    s = {1, 1, 1, 0},
                    r = {0, 0, 0, 1},
                    t = {2, 0, 0, 1},
                },
                name = 'hie_level1_1',
                hierarchy = {},
                serialize = seriazlizeutil.create(),
            }

    }

    local hie_level1_2 =
        world:create_entity {
            policy = default_hie_policy,
            data = {
                hierarchy_visible = true,
                transform = {
                    parent = hie_root,
                    s = {1, 1, 1, 0},
                    r = {0, 0, 0, 1},
                    t = {2, 0, 4, 1},
                },
                hierarchy = {},
                name = 'hie_level1_2',
                serialize = seriazlizeutil.create(),
            }
    }
    
    local hie_level2_1 =
        world:create_entity {
        policy = {
            "ant.render|name",
            "ant.scene|hierarchy",
            "ant.scene|ignore_parent_scale",
            "ant.serialize|serialize",
        },
        data = {
            hierarchy_visible = true,
            transform = {
                parent = hie_level1_2,
                s = {1, 1, 1, 0},
                r = {0, 0, 0, 1},
                t = {-2, 0, 0, 1},
            },
            hierarchy = {ref_path = hie_refpath,},
            ignore_parent_scale = true,
            name = 'hie_level2_1',
            serialize = seriazlizeutil.create(),
        }
    }
    local render_child1_1 =
        world:create_entity {
            policy = {
                "ant.render|render",
                "ant.render|mesh",
                "ant.render|name",
                "ant.objcontroller|select",
                "ant.serialize|serialize",
            },
            data = {
                transform = {
                    parent = hie_level1_1, 
                    s = {1, 1, 1, 0},
                    r = {0, 0, 0, 1},
                    t = {0, 0, 0, 1},
                },
                rendermesh = {},
                mesh = {
                    ref_path = fs.path '/pkg/ant.resources/depiction/meshes/sphere.mesh'
                },
                material = computil.assign_material(materialpath),

                name = 'render_child1_1',
                can_render = true,
                can_select = true,
                serialize = seriazlizeutil.create(),
            }
    }
    
    local render_child1_2 =
        world:create_entity {
            policy = {
                "ant.render|render",
                "ant.render|mesh",
                "ant.objcontroller|select",
                "ant.render|name",
                "ant.serialize|serialize",
            },
            data = {
                transform = {
                    parent = hie_level1_2, 
                    s = {1, 1, 1, 0},
                    r = {0, 0, 0, 1},
                    t = {0, 0, 0, 1},
                },
                name = 'render_child1_2',
                rendermesh = {},
                mesh = {
                    ref_path = fs.path '/pkg/ant.resources/depiction/meshes/sphere.mesh'
                },
                material = computil.assign_material(materialpath),
                can_render = true,
                can_select = true,
                serialize = seriazlizeutil.create(),
            }
        }

    local render_child2_1 =
        world:create_entity {
            policy = {
                "ant.render|render",
                "ant.render|mesh",
                "ant.objcontroller|select",
                "ant.serialize|serialize",
                "ant.render|name",
            },
            data = {
                transform = {
                    parent = hie_level2_1, 
                    s = {1, 1, 1, 0},
                    r = {0, 0, 0, 1},
                    t = {0, 2, 0, 1},
                },
                name = 'render_child2_1',
                rendermesh = {},
                mesh = {
                    ref_path = fs.path '/pkg/ant.resources/depiction/meshes/cube.mesh'
                },
                material = computil.assign_material(materialpath),
                can_render = true,
                can_select = true,
                serialize = seriazlizeutil.create(),
            }

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
            policy = default_hie_policy,
            data = {
                transform = mu.srt({2, 1, 1, 0}, nil, {3, 2, -3, 1}),
                hierarchy = {},
                hierarchy_visible = true,
                serialize = seriazlizeutil.create(),
                name = 'hie_root2',
            }
    }

    local hie2_level1_1 =
        world:create_entity {
            policy = default_hie_policy,
            data = {
                transform = {
                    s = {1, 1, 1, 0},
                    r = {0, 0, 0, 1},
                    t = {0, 5, 0, 1},
                    parent = hie_root2,
                },
                hierarchy = {},
                hierarchy_visible = true,
                name = 'hie2_level1_1',
                serialize = seriazlizeutil.create(),
            }
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
            policy = {
                "ant.objcontroller|select",
                "ant.render|name",
                "ant.render|render",
                "ant.render|mesh",
                "ant.serialize|serialize",
            },
            data = {
                transform = {
                    parent = hie_root2, 
                    s = {1, 1, 1, 0},
                    r = {0, 0, 0, 1},
                    t = {0, 2, -3, 1},
                },
                name = 'render2_rootchild',
                rendermesh = {},
                mesh = {
                    ref_path = fs.path '/pkg/ant.resources/depiction/meshes/cube.mesh'
                },
                material = computil.assign_material(materialpath),
                can_render = true,
                can_select = true,
                serialize = seriazlizeutil.create(),
            }

    }

    local render2_child1 =
        world:create_entity {
            policy = {
                "ant.objcontroller|select",
                "ant.render|name",
                "ant.render|render",
                "ant.render|mesh",
                "ant.serialize|serialize",
            },
            data = {
                transform = {
                    parent = hie2_level1_1,
                    s = {1, 1, 1, 0},
                    r = {0, 0, 0, 1},
                    t = {0, 0, 0, 1},
                },
                name = 'render2_child1',
                rendermesh = {},
                mesh = {
                    ref_path = fs.path '/pkg/ant.resources/depiction/meshes/sphere.mesh'
                },
                material    = computil.assign_material(materialpath),
                can_render  = true,
                can_select  = true,
                serialize   = seriazlizeutil.create(),
            }
        }

    local singlecolor_material = fs.path "/pkg/ant.resources/depiction/materials/singlecolor.material"

    local function create_material_item(filepath, color)
        return {
            ref_path = filepath,
            properties = {
                uniforms = {
                    u_color = {type = "color", name = "Color", value = color},
                }
            },
        }
    end

    local submesh_child = world:create_entity {
        policy = {
            "ant.serialize|serialize",
            "ant.render|name",
            "ant.render|render",
            "ant.render|mesh",
        },
        data = {
            transform = {
                parent = hie2_level1_1, 
                s = {0.1, 0.1, 0.1, 0},
                r = {0, 0, 0, 1},
                t = {0, 0, 0, 1},
            },
            name = 'submesh_child',
            rendermesh = {
                submesh_refs = {
                    build_big_storage_01_pillars_01     = computil.create_submesh_item {1},
                    build_big_storage_01_fence_02       = computil.create_submesh_item {2},
                    build_big_storage_01_walls_up       = computil.create_submesh_item {3},
                    build_big_storage_01_walls_down     = computil.create_submesh_item {4},
                    build_big_storage_01_straw_roof_002 = computil.create_submesh_item {5},
                },
            },
            mesh = {
                ref_path = fs.path '/pkg/ant.resources/depiction/meshes/build_big_storage_01.mesh',
            },
            material = {
                ref_path = singlecolor_material,
                properties = {uniforms = {
                        u_color = {type = "color", name = "Color", value = {1, 0, 0, 0}},
                    }},
                create_material_item(singlecolor_material, {0, 1, 0, 0}),
                create_material_item(singlecolor_material, {1, 0, 1, 0}),
                create_material_item(singlecolor_material, {1, 1, 0, 0}),
                create_material_item(singlecolor_material, {1, 1, 1, 0}),
            },
            can_render = true,
            can_select = true,
            serialize = seriazlizeutil.create(),
        },

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

    for _, eid in world:each "transform" do
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
    local oldvalue = ms(e.transform.t, "P")
    ms(e.transform.t, {10, 0, 0, 1}, "=")
    world:pub {"component_changed", "transform", eid, {
        field = "t",
        oldvalue = oldvalue,
        newvalue = ms(e.transform.t, "P"),
    }}
end

local test_queue = {
    idx=1,
    function ()
        local level1_2_eid = find_entity_by_name('hie_level1_2', 'hierarchy')
        if level1_2_eid then
            local level1_2 = world[level1_2_eid]
            local level1_2_trans = level1_2.transform
        
            local level1_1_eid = find_entity_by_name('hie_level1_1', 'hierarchy')
    
            local level1_1 = world[level1_1_eid]
            local level1_1_trans = level1_1.transform
            assert(level1_1_trans.parent == level1_2_trans.parent)
    
            local oldparent = level1_2_trans.parent
            level1_2_trans.parent = level1_1_eid
            world:pub {"component_changed", "transform", level1_2_eid, 
            {
                field = "parent",
                oldvalue = oldparent, newvalue = level1_1_eid,
            }}
                
        end
    end,
    function ()
        print_scene_nodes()
        print_tree()
    end,
    function ()
        local level1_1_eid = find_entity_by_name('hie_level1_1', 'transform')
        world:remove_entity(level1_1_eid)
        world:pub {"hierarchy_delete", level1_1_eid}
    end,
    function ()
        print_scene_nodes()
        print_tree()
    end,
    function ()
        move_root_node('hie_root2')
    end,
    function ()
        local eid = find_entity_by_name("render2_rootchild", 'can_render')
        world:add_policy(eid, {
            policy = {
                "ant.scene|hierarchy",
                "ant.scene|ignore_parent_scale",
            },
            data = {
                hierarchy = {},
                hierarchy_visible = true,
                ignore_parent_scale = true,
            }
        })
        world:create_entity {
            policy = {
                "ant.objcontroller|select",
                "ant.render|render",
                "ant.render|mesh",
                "ant.render|name",
            },
            data = {
                transform = {
                    s = {1, 1, 1, 0},
                    r = {0, 0, 0, 1},
                    t = {1, 2, 3, 1},
                    parent=eid,
                },
                rendermesh = {},
                material = {
                    ref_path = fs.path "/pkg/ant.resources/depiction/materials/singlecolor.material",
                    properties = {
                        uniforms = {u_color = {type="v4", name="color", value={1, 0.8, 0.8, 1}}}
                    }
                },
                mesh = {ref_path = fs.path '/pkg/ant.resources/depiction/meshes/cone.mesh'},
                can_render = true,
                can_select = true,
                name = 'test attach entity',
            },
        }
    end,
    function ()

    end,
}

function scenespace_test:data_changed()
    if test_queue.idx <= #test_queue then
        local op = test_queue[test_queue.idx]
        op()
        test_queue.idx = test_queue.idx + 1
    end
end

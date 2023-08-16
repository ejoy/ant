local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d= require "math3d"

local iom   = ecs.require "ant.objcontroller|obj_motion"

local hn_test_sys = ecs.system "hitch_node_test_system"
local hitch_test_group_id<const> = 1000
local skeleton_test_group_id<const> = 1001

local function create_simple_test_group()
    local defgroup = ecs.group(0)
    defgroup:create_entity {
        policy = {
            "ant.render|hitch_object",
            "ant.general|name",
        },
        data = {
            scene = {
                t = {0, 3, 0},
            },
            hitch = {
                group = hitch_test_group_id
            },
            visible_state = "main_view",
            name = "hitch_static1",
        }
    }
    defgroup:create_entity {
        policy = {
            "ant.render|hitch_object",
            "ant.general|name",
        },
        data = {
            scene = {
                t = {1, 2, 0},
            },
            hitch = {
                group = hitch_test_group_id
            },
            visible_state = "main_view",
            name = "hitch_static2",
        }
    }
    defgroup:create_entity {
        policy = {
            "ant.render|hitch_object",
            "ant.general|name",
        },
        data = {
            scene = {
                t = {0, 0, 3},
            },
            hitch = {
                group = hitch_test_group_id
            },
            visible_state = "main_view",
            name = "hitch_static2",
        }
    }

    local static_group = ecs.group(hitch_test_group_id)
    --standalone sub tree
    local p1 = static_group:create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/Cube_P1.meshbin",
            material = "/pkg/ant.resources.binary/meshes/base/cube.glb|materials/Material.001.material",
            visible_state = "main_view",
            scene = {},
            on_ready = function (e)
                iom.set_position(e, math3d.vector(0, 2, 0))
                --iom.set_scale(e, 3)
            end,
            name = "virtual_node_p1",
        },
    }

    static_group:create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/Cone_P1.meshbin",
            material = "/pkg/ant.resources.binary/meshes/base/cone.glb|materials/Material.001.material",
            visible_state = "main_view",
            scene = {
                parent = p1,
            },
            on_ready = function (e)
                iom.set_position(e, math3d.vector(1, 2, 3))
            end,
            name = "virtual_node",
        },
    }
end

local change_hitch_eid

local function create_skeleton_test_group()
    --dynamic
    ecs.create_entity {
        policy = {
            "ant.render|hitch_object",
            "ant.general|name",
        },
        data = {
            scene = {
                s = 0.1,
                t = {0.0, 0.0, -5.0},
            },
            hitch = {
                group = skeleton_test_group_id
            },
            visible_state = "main_view",
            name = "hitch_dynamic1",
        }
    }

    change_hitch_eid = ecs.create_entity {
        policy = {
            "ant.render|hitch_object",
            "ant.general|name",
        },
        data = {
            scene = {
                s = 0.1,
                r = {0.0, 0.8, 0.0},
                t = {5.0, 0.0, 0.0},
            },
            hitch = {
                group = skeleton_test_group_id
            },
            visible_state = "main_view",
            name = "hitch_dynamic2",
        }
    }

    local function create_obj(g, file, s, t)
        local p = g:create_instance(file)
        p.on_ready = function (e)
            local ee<close> = world:entity(e.tag['*'][1], "scene:in")
            if s then
                iom.set_scale(ee, s)
            end
            if t then
                iom.set_position(ee, t)
            end
        end
        world:create_object(p)
    end

    local dynamic_group = ecs.group(skeleton_test_group_id)
    create_obj(dynamic_group, "/pkg/ant.resources.binary/meshes/BrainStem.glb|mesh.prefab", 10)

    local d2g = ecs.group(skeleton_test_group_id+1)
    create_obj(d2g, "/pkg/ant.resources.binary/meshes/chimney-1.glb|mesh.prefab")
end

function hn_test_sys:init()
    create_simple_test_group()
    --create_skeleton_test_group()
end

local TICK = 0

local key_mb = world:sub {"keyboard"}
function hn_test_sys:data_changed()
    for _, key, press in key_mb:unpack() do
        if key == "Y" and press == 0 then
            local e <close> = w:entity(change_hitch_eid, "hitch:update hitch_bounding?out")
            e.hitch.group = skeleton_test_group_id+1
            e.hitch_bounding = true
        end
    end

    -- if TICK == 20 then
    --     local queuemgr = ecs.require "ant.render|queue_mgr"
    --     local mainmask = queuemgr.queue_mask "main_queue"
    --     for e in w:select "hitch:in name:in" do
    --         print("hitch object:", e.name, 0 ~= (e.hitch.cull_masks & mainmask) and "culled" or "not culled")
    --     end

    --     TICK = 0
    -- else
    --     TICK = TICK + 1
    -- end
    
end

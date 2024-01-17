local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d= require "math3d"

local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()
local iom   = ecs.require "ant.objcontroller|obj_motion"
local ig    = ecs.require "ant.group|group"
local hn_test_sys = common.test_system "hitch_node"

local function create_simple_test_group()
    local hitch_test_group_id<const>    = ig.register "hitch_node_test"
    PC:create_entity {
        policy = {
            "ant.render|hitch_object",
        },
        data = {
            scene = {
                t = {0, 3, 0},
            },
            hitch = {
                group = hitch_test_group_id
            },
            visible_state = "main_view",
        }
    }
    PC:create_entity {
        policy = {
            "ant.render|hitch_object",
        },
        data = {
            scene = {
                t = {1, 2, 0},
            },
            hitch = {
                group = hitch_test_group_id
            },
            visible_state = "main_view",
        }
    }
    PC:create_entity {
        policy = {
            "ant.render|hitch_object",
        },
        data = {
            scene = {
                t = {0, 0, 3},
            },
            hitch = {
                group = hitch_test_group_id
            },
            visible_state = "main_view",
        }
    }

    --standalone sub tree
    local p1 = PC:create_entity {
        group = hitch_test_group_id,
        policy = {
            "ant.render|render",
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
        },
    }

    PC:create_entity {
        group = hitch_test_group_id,
        policy = {
            "ant.render|render",
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
        },
    }
end

local change_hitch_eid

local function create_skeleton_test_group()
    local skeleton_test_group_id<const> = ig.register "hitch_node_ske_test"
    --dynamic
    PC:create_entity {
        policy = {
            "ant.render|hitch_object",
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
        }
    }

    change_hitch_eid = PC:create_entity {
        policy = {
            "ant.render|hitch_object",
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
        }
    }

    local function create_obj(gid, file, s, t)
        PC:create_instance {
            prefab = file,
            group = gid,
            on_ready = function (e)
                local ee<close> = world:entity(e.tag['*'][1], "scene:in")
                if s then
                    iom.set_scale(ee, s)
                end
                if t then
                    iom.set_position(ee, t)
                end
            end
        }
    end

    create_obj(skeleton_test_group_id, "/pkg/ant.resources.binary/meshes/BrainStem.glb|mesh.prefab", 10)
    create_obj(skeleton_test_group_id+1, "/pkg/ant.resources.binary/meshes/chimney-1.glb|mesh.prefab")
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
            if not ig.has "hitch_ske_test1" then
                ig.register "hitch_ske_test1"
            end
            e.hitch.group = ig.groupid "hitch_ske_test1"
            e.hitch_bounding = true
        end
    end

    -- if TICK == 20 then
    --     local queuemgr = ecs.require "ant.render|queue_mgr"
    --     local mainmask = queuemgr.queue_mask "main_queue"
    --     for e in w:select "hitch:in" do
    --         print("hitch object:", e.name, 0 ~= (e.hitch.cull_masks & mainmask) and "culled" or "not culled")
    --     end

    --     TICK = 0
    -- else
    --     TICK = TICK + 1
    -- end
    
end

function hn_test_sys:exit()
    PC:clear()
end
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

local h1, h2, h3
local hitch_test_group_id<const>    = ig.register "hitch_node_test"
local TEST_INDIRECT<const> = true

local function create_simple_test_group()
    h1 = PC:create_entity {
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
            visible_state = "main_view|cast_shadow|selectable",
            hitch_create = TEST_INDIRECT,
        }
    }
    h2 = PC:create_entity {
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
            visible_state = "main_view|cast_shadow|selectable",
            hitch_create = TEST_INDIRECT,
        }
    }

    local prefabname = TEST_INDIRECT and "mesh_di.prefab" or "mesh.prefab"

    --standalone sub tree
    local p1 = PC:create_instance {
        group = hitch_test_group_id,
        prefab = "/pkg/ant.resources.binary/meshes/base/cube.glb|" .. prefabname,
        on_ready = function (p)
            local root<close> = world:entity(p.tag['*'][1], "scene:update")
            iom.set_position(root, math3d.vector(0, 2, 0))
        end,
    }

    PC:create_instance {
        group = hitch_test_group_id,
        prefab = "/pkg/ant.resources.binary/meshes/base/cone.glb|" .. prefabname,
        on_ready = function (p)
            local root<close> = world:entity(p.tag['*'][1], "scene:update scene_needchange?out")
            iom.set_position(root, math3d.vector(1, 2, 3))
            root.scene.parent = p1.tag['*'][1]
            root.scene_needchange = true
        end,
    }
end

function hn_test_sys:init()
    create_simple_test_group()
    PC:add_entity(util.create_shadow_plane(25))
end

local key_mb = world:sub {"keyboard"}
function hn_test_sys:data_changed()
    for _, key, press in key_mb:unpack() do
        if key == "A" and press == 0 then
            local e <close> = world:entity(h1, "eid:in")
            w:remove(h1)
        elseif key == "B" and press == 0 then
            local e <close> = world:entity(h2, "scene:update")
            iom.set_position(e, math3d.tovalue(math3d.add(math3d.vector(0, 3, 0), e.scene.t)))
        elseif key == "C" and press == 0 then
            h3 = PC:create_entity {
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
        end
    end

end

function hn_test_sys:exit()
    PC:clear()
end
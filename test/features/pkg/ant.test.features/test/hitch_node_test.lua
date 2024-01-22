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
            visible_state = "main_view",
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

function hn_test_sys:init()
    create_simple_test_group()
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
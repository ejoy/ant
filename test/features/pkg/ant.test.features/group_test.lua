local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d= require "math3d"

local ig    = ecs.require "ant.group|group"
local iom   = ecs.require "ant.objcontroller|obj_motion"
local group_test_sys = ecs.system "group_test_system"

function group_test_sys:init()
    local g1 = ig.register "group_test1"
    local g2 = ig.register "group_test2"

    world:create_instance {
        prefab = "/pkg/ant.resources.binary/meshes/base/cube.glb|mesh.prefab",
        group = g1,
        on_ready = function(e)
            local eid = e.tag['*'][1]
            local ee<close> = world:entity(eid, "scene:in")
            iom.set_position(ee, math3d.vector(5, 0, 0, 1))
        end
    }

    world:create_instance {
        prefab = "/pkg/ant.resources.binary/meshes/base/cone.glb|mesh.prefab",
        group = g1,
        on_ready = function(e)
            local eid = e.tag['*'][1]
            local ee<close> = world:entity(eid, "scene:in")
        end
    }

    world:create_instance {
        prefab = "/pkg/ant.resources.binary/meshes/base/cylinder.glb|mesh.prefab",
        group = g2,
        on_ready = function(e)
            local eid = e.tag['*'][1]
            local ee<close> = world:entity(eid, "scene:in")
            iom.set_position(ee, math3d.vector(10, 0, 0, 1))
        end
    }

    world:create_instance {
        prefab = "/pkg/ant.resources.binary/meshes/base/ring.glb|mesh.prefab",
        group = g2,
        on_ready = function(e)
            local eid = e.tag['*'][1]
            local ee<close> = world:entity(eid, "scene:in")
            iom.set_position(ee, math3d.vector(10, 0, 10, 1))
        end
    }
end

local kb_mb = world:sub{"keyboard"}

local gname = "group_test1"
function group_test_sys:data_changed()
    for _, key, press in kb_mb:unpack() do
        if key == "G" and press == 0 then
            local gn1 = gname
            local gn2 = gname == "group_test1" and "group_test2" or "group_test1"

            ig.enable_from_name(gn1, "view_visible", gn1 == "group_test1")
            ig.enable_from_name(gn2, "view_visible", gn2 == "group_test1")
            
            gname = gn2
        end
    end
end
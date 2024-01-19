local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"
local common    = ecs.require "common"

local efk_test_sys = common.test_system "efk"

local iefk      = ecs.require "ant.efk|efk"
local ig        = ecs.require "ant.group|group"
local iom       = ecs.require "ant.objcontroller|obj_motion"

local util		= ecs.require "util"

local PC		= util.proxy_creator()

local function hitch_test()
    local test_gid<const> = ig.has "hitch_test" or ig.register "hitch_test"
    
    local eid = PC:create_entity{
        group = test_gid,
        policy = {
            "ant.scene|scene_object",
            "ant.efk|efk",
        },
        data = {
            scene = {},
            efk = {
                path = "/pkg/ant.test.features/assets/efk/miner_efk/miner_dust.efk",
            },
            visible_state = "main_queue",
        }
    }

    PC:create_entity{
        policy = {
            "ant.render|hitch_object",
        },
        data = {
            hitch = {
                group = test_gid,
            },
            visible_state = "main_view",
            scene = {
                t = {5, 2, 0, 1}
            },
            view_visible = true,
            on_ready = function (e)
                w:extend(e, "view_visible?in")
                print(e.view_visible)
            end
        }
    }

    return eid
end

local function simple_test()
    PC:create_entity{
        policy = {
            "ant.scene|scene_object",
            "ant.efk|efk",
        },
        data = {
            scene = {
                t = {-2, 0, 0, 1}
            },
            efk = {
                path = "/pkg/ant.test.features/assets/efk/miner_efk/miner_dust.efk",
            },
            visible_state = "main_queue",
        }
    }

    PC:create_entity{
        policy = {
            "ant.scene|scene_object",
            "ant.efk|efk",
        },
        data = {
            scene = {
                t = {3, 0, 0, 1}
            },
            efk = {
                path = "/pkg/ant.test.features/assets/efk/miner_efk/miner_dust.efk",
            },
            visible_state = "main_queue",
        }
    }
end

local efkeid_group
function efk_test_sys:init()
    hitch_test()
end

function efk_test_sys:init_world()
    local mq = w:first "main_queue camera_ref:in"
    local ce <close> = world:entity(mq.camera_ref)
    iom.set_position(ce, math3d.vector(0.0, 0.0, 10.0))
    iom.set_direction(ce, math3d.vector(0.0, 0.0, -1.0))
end


local kb_mb = world:sub{"keyboard"}
function efk_test_sys:data_changed()
    for _, key, press in kb_mb:unpack() do
        if press == 0 and key == "T" then
            local e <close> = world:entity(efkeid_group, "efk:in")
            iefk.stop(e)
        elseif press == 0 and key == "R" then
            print(w:count "hitch")
            print(w:count "hitch view_visible")
        end
    end
end

function efk_test_sys:exit()
    PC:clear()
end
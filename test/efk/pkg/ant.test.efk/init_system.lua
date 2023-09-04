local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"

local iefk      = ecs.require "ant.efk|efk"
local iom       = ecs.require "ant.objcontroller|obj_motion"

local is = ecs.system "init_system"

local test_gid<const> = 1000001
local efkeid
function is:init()
    iefk.preload{
        "/pkg/ant.test.efk/assets/miner_efk/a1.texture",
        "/pkg/ant.test.efk/assets/miner_efk/a2.texture",
        "/pkg/ant.test.efk/assets/miner_efk/a3.texture",
    }

    efkeid = world:create_entity{
        group = test_gid,
        policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.efk|efk",
        },
        data = {
            name = "root",
            scene = {},
            efk = {
                path = "/pkg/ant.test.efk/assets/miner_efk/miner_dust.efk",
                auto_play = true,
                loop = true,
                visible = false,
            },
            visible_state = "main_queue",
        }
    }

    if nil ~= test_gid then
        world:create_entity{
            policy = {
                "ant.general|name",
                "ant.render|hitch_object",
            },
            data = {
                name = "test_efk_hitch",
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

        world:group_disable_tag("view_visible", 0)
    end
end

function is:init_world()

    local mq = w:first "main_queue camera_ref:in"
    local ce <close> = world:entity(mq.camera_ref)
    iom.set_position(ce, math3d.vector(0.0, 0.0, 10.0))
    iom.set_direction(ce, math3d.vector(0.0, 0.0, -1.0))
end

local kb_mb = world:sub{"keyboard"}
function is:data_changed()
    for _, key, press in kb_mb:unpack() do
        if press == 0 and key == "T" then
            iefk.stop(efkeid)
        elseif press == 0 and key == "R" then
            print(w:count "hitch")
            print(w:count "hitch view_visible")
        end
    end
end
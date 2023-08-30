local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"

local iefk      = ecs.require "ant.efk|efk"
local iom       = ecs.require "ant.objcontroller|obj_motion"

local is = ecs.system "init_system"

local test_gid<const> = 1000001
function is:init()
    iefk.preload{
        "/pkg/ant.test.efk/assets/miner_efk/a1.texture",
        "/pkg/ant.test.efk/assets/miner_efk/a2.texture",
        "/pkg/ant.test.efk/assets/miner_efk/a3.texture",
    }

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
            }
        }
    }

    world:create_entity({
        policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.efk|efk",
            "ant.general|tag"
        },
        data = {
            name = "root",
            tag = {"effect"},
            scene = {},
            efk = {
                path = "/pkg/ant.test.efk/assets/miner_efk/miner_dust.efk",
                auto_play = true,
                loop = true,
                visible = false,
            },
            view_visible = false,
            on_ready = function (e)
                if nil ~= test_gid then
                    w:extend(e, "view_visible?out")
                    e.view_visible = false
                    w:submit(e)
                end
            end
        },
    }, test_gid)

    world:group_enable_tag("view_visible", test_gid)
    world:group_flush "view_visible"
end

function is:init_world()

    local mq = w:first "main_queue camera_ref:in"
    local ce <close> = world:entity(mq.camera_ref)
    iom.set_position(ce, math3d.vector(0.0, 0.0, 10.0))
    iom.set_direction(ce, math3d.vector(0.0, 0.0, -1.0))
end

function is:data_changed()

end
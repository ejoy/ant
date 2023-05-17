local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"

local iefk      = ecs.import.interface "ant.efk|iefk"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"

local is = ecs.system "init_system"

function is:init()
    iefk.preload{
        "/pkg/ant.test.efk/assets/miner_efk/a1.texture",
        "/pkg/ant.test.efk/assets/miner_efk/a2.texture",
        "/pkg/ant.test.efk/assets/miner_efk/a3.texture",
    }

    iefk.create("/pkg/ant.test.efk/assets/miner_efk/miner_dust.efk", {
        visible = true,
        loop = true,
        auto_play = true
    })
end

function is:init_world()

    local mq = w:first "main_queue camera_ref:in"
    local ce <close> = w:entity(mq.camera_ref)
    iom.set_position(ce, math3d.vector(0.0, 0.0, 10.0))
    iom.set_direction(ce, math3d.vector(0.0, 0.0, -1.0))
end

function is:data_changed()

end
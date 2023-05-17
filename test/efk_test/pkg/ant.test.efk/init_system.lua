local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"

local iefk      = ecs.import.interface "ant.efk|iefk"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"

local is = ecs.system "init_system"

function is:init()
    
end

function is:init_world()
    iefk.create "/pkg/ant.test.efk/assets/miner_efk/miner_dust.efk"
    
    local mq = w:first "main_queue camera_ref:in"
    local ce <close> = w:entity(mq.camera_ref)
    iom.set_position(ce, math3d.vector(0.0, 0.0, 10.0))
    iom.set_direction(ce, math3d.vector(0.0, 0.0, -1.0))
end

function is:data_changed()

end
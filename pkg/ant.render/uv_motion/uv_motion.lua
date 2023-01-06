local ecs   = ...
local world = ecs.world
local w     = world.w

local iuvm = ecs.interface "iuv_motion"
local imaterial = ecs.import.interface "ant.asset|imaterial"

function iuvm.set_speed(e, speed)
    imaterial.set_property(e, "u_motion_speed", {speed[1], speed[2], 0.0, 0.0})
end
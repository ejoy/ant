local ecs   = ...
local world = ecs.world
local w     = world.w

local iuvm = {}
local imaterial = ecs.require "ant.asset|material"

function iuvm.set_speed(e, speed)
    imaterial.set_property(e, "u_motion_speed", {speed[1], speed[2], 0.0, 0.0})
end

return iuvm

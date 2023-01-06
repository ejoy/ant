local ecs   = ...
local world = ecs.world
local w     = world.w

local setting = import_package "ant.settings".setting
local cw = setting:data().graphic.curve_world
local icw = ecs.interface "icurve_world"

--runtime disable
local last_curve_rate = cw.curve_rate
function icw.enable(e)
    if e ~= nil then
        setting:set("graphic/curve_world/curve_rate", e and last_curve_rate or 0.0)
        setting:set("graphic/curve_world/enable", e)
    else
        return cw.enable
    end
end

function icw.param()
    return cw
end
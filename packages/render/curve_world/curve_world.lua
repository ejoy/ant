local ecs   = ...
local world = ecs.world
local w     = world.w

local setting = import_package "ant.settings".setting
local cw = setting:data().graphic.curve_world
local icw = ecs.interface "icurve_world"

--runtime disable
local last_max_range = cw.max_range
function icw.enable(e)
    if e ~= nil then
        setting:set("graphic/curve_world/max_range", e and last_max_range or 0.0)
        setting:set("graphic/curve_world/enable", e)
    else
        return cw.enable
    end
end

function icw.param()
    return cw
end
local ecs           = ...
local world         = ecs.world
local w             = world.w

local dnui_sys   = ecs.system 'daynight_ui_system'
local idn           = ecs.import.interface "ant.daynight|idaynight"
local itimer        = ecs.import.interface "ant.timer|itimer"

function dnui_sys:data_changed()
    local dne = w:first "daynight:in"
    if dne then
        local tenSecondMS<const> = 10000
        local cycle = (itimer.current() % tenSecondMS) / tenSecondMS
        idn.update_cycle(dne, cycle)
    end
end

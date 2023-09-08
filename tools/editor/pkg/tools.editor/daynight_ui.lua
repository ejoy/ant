local ecs           = ...
local world         = ecs.world
local w             = world.w

local dnui_sys   = ecs.system 'daynight_ui_system'
local idn           = ecs.require "ant.daynight|daynight"
local itimer        = ecs.require "ant.timer|timer_system"

function dnui_sys:data_changed()
    local dne = w:first "daynight:in"
    if dne then
        local tenSecondMS<const> = 10000
        local cycle = (itimer.current() % tenSecondMS) / tenSecondMS
        idn.update_cycle(dne, cycle)
    end
end

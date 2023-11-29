local ecs           = ...
local world         = ecs.world
local w             = world.w

local dnui_sys      = ecs.system 'daynight_ui_system'
local idn           = ecs.require "ant.daynight|daynight"
local itimer        = ecs.require "ant.timer|timer_system"
local idnui = {}

local sum_second = 10000
local base_second <const> = 1000
local factor_second = 10
local last_cycle = 0
local type = 0

function dnui_sys:data_changed()
    local cycle = (itimer.current() % sum_second) / sum_second
    if last_cycle > cycle then
        type = type == 0 and 1 or 0
    end
    for e in w:select "daynight:in" do
        if e.daynight.type == type then
            idn.update_cycle(e, cycle)
        end
    end
    last_cycle = cycle
end

function idnui.set_daynight_cycle(cycle)
    factor_second = cycle
    sum_second = base_second * factor_second
end

function idnui.get_daynight_cycle()
    return factor_second
end


return idnui
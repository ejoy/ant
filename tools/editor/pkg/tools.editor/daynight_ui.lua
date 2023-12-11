local ecs           = ...
local world         = ecs.world
local w             = world.w

local dnui_sys      = ecs.system 'daynight_ui_system'
local idn           = ecs.require "ant.daynight|daynight"

local idnui = {}

local ltask = require "ltask"

local function gettime()
    local _, now = ltask.now()
    return now * 10
end

local sum_second = 10000
local base_second <const> = 1000
local factor_second = 10

function dnui_sys:data_changed()
    local dne = w:first "daynight:in"
    if dne then
        local cycle = (gettime() % sum_second) / sum_second
        idn.update_cycle(dne, cycle)
    end
end

function idnui.set_daynight_cycle(cycle)
    factor_second = cycle
    sum_second = base_second * factor_second
end

function idnui.get_daynight_cycle()
    return factor_second
end


return idnui
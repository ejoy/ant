local ecs = ...
local world = ecs.world

local m = {}

local systems = {}

function m.test_system(name)
    local sysname = name .. "_test_system"
    local fullname = "ant.test.features|" .. sysname
    local s = ecs.system(sysname)
    world:disable_system(fullname)
    systems[name] = fullname
    return s
end

function m.get_systems()
    return systems
end

m.init_system = "<none>"

return m

local ecs = ...
local world = ecs.world

local m = {}

local systems = {}

function m.enable_test(name)
    if name == "<none>" then
        return
    end
    if name == "<all>" then
        for _, fullname in pairs(systems) do
            world:enable_system(fullname)
        end
        return
    end
    world:enable_system(systems[name])
end

function m.disable_test(name)
    if name == "<none>" then
        return
    end
    if name == "<all>" then
        for _, fullname in pairs(systems) do
            world:disable_system(fullname)
        end
        return
    end
    world:disable_system(systems[name])
end

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

local s = ecs.system "test_init_system"
function s.init()
    m.enable_test(m.init_system)
end

return m

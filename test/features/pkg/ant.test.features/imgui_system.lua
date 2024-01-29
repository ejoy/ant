local ecs = ...
local world = ecs.world
local w = world.w

local ImGui = import_package "ant.imgui"
local common = ecs.require "common"

local m = ecs.system "imgui_system"

local currentTest
local function enable_test(name)
    currentTest = name
    if name == "<none>" then
        return
    end
    local systems = common.get_systems()
    if name == "<all>" then
        for _, fullname in pairs(systems) do
            world:enable_system(fullname)
        end
        return
    end
    world:enable_system(systems[name])
end

local function disable_test(name)
    if name == "<none>" then
        return
    end
    local systems = common.get_systems()
    if name == "<all>" then
        for _, fullname in pairs(systems) do
            world:disable_system(fullname)
        end
        return
    end
    world:disable_system(systems[name])
end

local function select_test(name)
    if ImGui.Selectable(name, name == currentTest) then
        if currentTest ~= name then
            disable_test(currentTest)
            enable_test(name)
        end
    end
end

function m:init()
    enable_test(common.init_system)
end

function m:data_changed()
    if ImGui.Begin("test", nil, ImGui.Flags.Window {"AlwaysAutoResize", "NoMove", "NoTitleBar"}) then
        if ImGui.BeginCombo("##test", currentTest) then
            select_test "<none>"
            select_test "<all>"
            for name in pairs(common.get_systems()) do
                select_test(name)
            end
            ImGui.EndCombo()
        end
    end
    ImGui.End()
end

local ecs = ...
local world = ecs.world
local w = world.w

local ImGui = require "imgui"
local common = ecs.require "common"

local m = ecs.system "imgui_system"
local current_test
local function select_test(name)
    if ImGui.SelectableEx(name, name == current_test) then
        if current_test ~= name then
            common.disable_test(current_test)

            current_test = name
            common.enable_test(name)
        end
    end
end

function m:data_changed()
    if ImGui.Begin("test", nil, ImGui.WindowFlags {"AlwaysAutoResize", "NoMove", "NoTitleBar"}) then
        current_test = current_test or common.init_system
        if ImGui.BeginCombo("##test", current_test) then
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

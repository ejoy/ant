local ecs = ...
local world = ecs.world
local w = world.w

local ImGui = import_package "ant.imgui"
local ImGuiLegacy = require "imgui.legacy"

local m = ecs.system 'init_system'

local text = {text = ""}

local DropfilesEvent = world:sub { "dropfiles" }

function m:init()
    ImGui.SetViewClear("C", 0x000000ff, 1.0, 0.0)
end

function m:data_changed()
    for _, e in DropfilesEvent:unpack() do
        print("dropfiles:", e.files[1])
    end
    if ImGui.Begin("test", nil, ImGui.WindowFlags {'AlwaysAutoResize'}) then
        if ImGui.TreeNodeEx("Test", ImGui.TreeNodeFlags {"DefaultOpen"}) then
            if ImGuiLegacy.InputText("TEST", text) then
                print(tostring(text.text))
            end
            ImGui.TreePop()
        end
    end
    ImGui.End()
end

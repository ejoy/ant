local ecs = ...
local world = ecs.world
local w = world.w

local ImGui = import_package "ant.imgui"

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
    if ImGui.Begin ("test", nil, ImGui.Flags.Window {'AlwaysAutoResize'}) then
        if ImGui.TreeNode("Test", ImGui.Flags.TreeNode{"DefaultOpen"}) then
            if ImGui.InputText("TEST", text) then
                print(tostring(text.text))
            end
            ImGui.TreePop()
        end
    end
    ImGui.End()
end

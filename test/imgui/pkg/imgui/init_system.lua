local ecs = ...
local world = ecs.world
local w = world.w

local imgui = require "imgui"

local m = ecs.system 'init_system'

local text = {text = ""}

local DropfilesEvent = world:sub { "dropfiles" }

function m:data_changed()
    for _, e in DropfilesEvent:unpack() do
        print("dropfiles:", e.files[1])
    end
    if imgui.windows.Begin ("test", imgui.flags.Window {'AlwaysAutoResize'}) then
        if imgui.widget.TreeNode("Test", imgui.flags.TreeNode{"DefaultOpen"}) then
            if imgui.widget.InputText("TEST", text) then
                print(tostring(text.text))
            end
            imgui.widget.TreePop()
        end
    end
    imgui.windows.End()
end

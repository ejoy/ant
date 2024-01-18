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

local bgfx = require "bgfx"
local rhwi = import_package "ant.hwi"

function m:end_frame()
	local viewId = rhwi.viewid_get("imgui_eidtor" .. 1)
    bgfx.set_view_clear(viewId, "C", 0x000000ff, 1.0, 0.0)
end

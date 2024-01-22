local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local uiconfig  = require "widget.config"
local icons     = require "common.icons"
local ImGui = import_package "ant.imgui"
local irq   = ecs.require "ant.render|render_system.renderqueue"
local iviewport = ecs.require "ant.render|viewport.state"

local drag_file

local m = {}

local function cvt2scenept(x, y)
    return x - iviewport.device_size.x, y - iviewport.device_size.y
end

local function in_view(x, y)
    return mu.pt2d_in_rect(x, y, irq.view_rect "main_queue")
end

function m.show()
    local imgui_vp = ImGui.GetMainViewport()
    if not icons.scale then
        icons.scale = imgui_vp.DpiScale
    end
    --drag file to view
    if ImGui.IsMouseDragging(0) then
        local x, y = ImGui.GetMousePos()
        x, y = x - imgui_vp.MainPos[1], y - imgui_vp.MainPos[2]
        if in_view(cvt2scenept(x, y)) then
            if not drag_file then
                local dropdata = ImGui.GetDragDropPayload()
                if dropdata and (string.sub(dropdata, -7) == ".prefab"
                    or string.sub(dropdata, -4) == ".efk" or string.sub(dropdata, -4) == ".glb") then
                    drag_file = dropdata
                end
            end
        else
            drag_file = nil
        end
    else
        if drag_file then
            world:pub {"AddPrefabOrEffect", drag_file}
            drag_file = nil
        end
    end

    local wp, ws = imgui_vp.WorkPos, imgui_vp.WorkSize
    local posx, posy = wp[1], wp[2]+uiconfig.ToolBarHeight
    local sizew, sizeh = ws[1], ws[2]-uiconfig.ToolBarHeight
    ImGui.SetNextWindowPos(posx, posy)
    ImGui.SetNextWindowSize(sizew, sizeh)
    ImGui.SetNextWindowViewport(imgui_vp.ID)
	ImGui.PushStyleVar(ImGui.Enum.StyleVar.WindowRounding, 0.0);
	ImGui.PushStyleVar(ImGui.Enum.StyleVar.WindowBorderSize, 0.0);
    ImGui.PushStyleVar(ImGui.Enum.StyleVar.WindowPadding, 0.0, 0.0);
    if ImGui.Begin("MainView", ImGui.Flags.Window {
        "NoDocking",
        "NoTitleBar",
        "NoCollapse",
        "NoResize",
        "NoMove",
        "NoBringToFrontOnFocus",
        "NoNavFocus",
        "NoBackground",
    }) then
        ImGui.DockSpace("MainViewSpace", ImGui.Flags.DockNode {
            "NoDockingOverCentralNode",
            "PassthruCentralNode",
        })
        --NOTE: the coordinate reture from BuilderGetCentralRect function is relative to full viewport
        local x, y, ww, hh = ImGui.DockBuilderGetCentralRect "MainViewSpace"
        local mp = imgui_vp.MainPos
        x, y = x - mp[1], y - mp[2]
        local vp = iviewport.device_size
        if x ~= vp.x or y ~= vp.y or ww ~= vp.w or hh ~= vp.h then
            vp.x, vp.y, vp.w, vp.h = x, y, ww, hh
            world:dispatch_message {
                type = "set_viewport",
                viewport = vp,
            }
        end
    end
    ImGui.PopStyleVar(3)
    ImGui.End()
end

return m
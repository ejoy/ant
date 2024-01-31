local ecs   = ...
local world = ecs.world
local w     = world.w
local platform     = require "bee.platform"
local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local uiconfig  = require "widget.config"
local icons     = require "common.icons"
local ImGui = import_package "ant.imgui"
local ImGuiLegacy = require "imgui.legacy"
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
    local viewport = ImGui.GetMainViewport()
    if not icons.scale then
        icons.scale = viewport.DpiScale
    end
    --drag file to view
    if ImGui.IsMouseDragging(ImGui.MouseButton.Left) then
        local x, y = ImGui.GetMousePos()
        x, y = x - viewport.Pos.x, y - viewport.Pos.y
        if in_view(cvt2scenept(x, y)) then
            if not drag_file then
                local dropdata = ImGui.GetDragDropPayload()
                if dropdata and (string.sub(dropdata, -7) == ".prefab"
                    or string.sub(dropdata, -4) == ".efk" or string.sub(dropdata, -4) == ".glb" or string.sub(dropdata, -5) == ".gltf") then
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

    local posx, posy = viewport.WorkPos.x, viewport.WorkPos.y + uiconfig.ToolBarHeight
    local sizew, sizeh = viewport.WorkSize.x, viewport.WorkSize.y - uiconfig.ToolBarHeight
    ImGui.SetNextWindowPos(posx, posy)
    ImGui.SetNextWindowSize(sizew, sizeh)
    ImGui.SetNextWindowViewport(viewport.ID)
	ImGui.PushStyleVar(ImGui.StyleVar.WindowRounding, 0.0);
	ImGui.PushStyleVar(ImGui.StyleVar.WindowBorderSize, 0.0);
    ImGui.PushStyleVarImVec2(ImGui.StyleVar.WindowPadding, 0.0, 0.0);
    if ImGui.Begin("MainView", nil, ImGui.WindowFlags {
        "NoDocking",
        "NoTitleBar",
        "NoCollapse",
        "NoResize",
        "NoMove",
        "NoBringToFrontOnFocus",
        "NoNavFocus",
        "NoBackground",
    }) then
        ImGui.DockSpaceEx(ImGui.GetID "MainViewSpace", 0, 0, ImGui.DockNodeFlags {
            "NoDockingOverCentralNode",
            "PassthruCentralNode",
        })
        --NOTE: the coordinate reture from BuilderGetCentralRect function is relative to full viewport
        local x, y, ww, hh = ImGuiLegacy.DockBuilderGetCentralRect "MainViewSpace"
        x, y = x - viewport.Pos.x, y - viewport.Pos.y
        local vp = iviewport.device_size
        if x ~= vp.x or y ~= vp.y or ww ~= vp.w or hh ~= vp.h then
            if platform.os == "macos" then
                vp.x = x * viewport.DpiScale
                vp.y = y * viewport.DpiScale
                vp.w = ww * viewport.DpiScale
                vp.h = hh * viewport.DpiScale
            else
                vp.x, vp.y, vp.w, vp.h = x, y, ww, hh
            end
            world:dispatch_message {
                type = "set_viewport",
                viewport = vp,
            }
        end
    end
    ImGui.PopStyleVarEx(3)
    ImGui.End()
end

return m
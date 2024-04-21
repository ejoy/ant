local ecs   = ...
local world = ecs.world
local w     = world.w
local platform     = require "bee.platform"
local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local uiconfig  = require "widget.config"
local icons     = require "common.icons"
local ImGui = require "imgui"
local ImGuiInternal = require "imgui.internal"
local irq   = ecs.require "ant.render|renderqueue"
local iviewport = ecs.require "ant.render|viewport.state"

local drag_file

local m = {}

--x, y in scene view space
local function in_view(x, y)
    return mu.pt2d_in_rect(x, y, iviewport.viewrect)
end

local last_vr = {x=0, y=0, w=0, h=0}

local function is_viewrect_different(lhs, rhs)
    return lhs.x ~= rhs.x or lhs.x ~= rhs.x or lhs.w ~= rhs.w or lhs.h ~= rhs.h
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
        if in_view(iviewport.cvt2scenept(x, y)) then
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
        local node_id = ImGui.GetID "MainViewSpace"
        ImGui.DockSpaceEx(node_id, 0, 0, ImGui.DockNodeFlags {
            "NoDockingOverCentralNode",
            "PassthruCentralNode",
        })
        --NOTE: the coordinate reture from BuilderGetCentralRect function is relative to full viewport
        local dock_vr = {}
        dock_vr.x, dock_vr.y, dock_vr.w, dock_vr.h = ImGuiInternal.DockBuilderGetCentralRect(node_id)

        local function scale_with_dpi(vr, offset)
            vr.x, vr.y = vr.x - offset.x, vr.y - offset.y
            if platform.os == "macos" then
                return {
                    x = vr.x * viewport.DpiScale,
                    y = vr.y * viewport.DpiScale,
                    w = vr.w * viewport.DpiScale,
                    h = vr.h * viewport.DpiScale,
                }
            end

            return vr
        end

        dock_vr = scale_with_dpi(dock_vr, viewport.Pos)

        if is_viewrect_different(dock_vr, last_vr) then
            --copy it
            last_vr.x, last_vr.y, last_vr.w, last_vr.h = dock_vr.x, dock_vr.y, dock_vr.w, dock_vr.h
            iviewport.set_device_viewrect(last_vr)
            world:dispatch_message {
                type        = "scene_viewrect",
                viewrect    = dock_vr,
            }
        end
    end
    ImGui.PopStyleVarEx(3)
    ImGui.End()
end

return m
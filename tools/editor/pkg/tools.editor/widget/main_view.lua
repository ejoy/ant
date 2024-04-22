local ecs   = ...
local world = ecs.world

local platform      = require "bee.platform"
local mathpkg       = import_package "ant.math"
local mu            = mathpkg.util
local icons         = require "common.icons"
local iviewport = ecs.require "ant.render|viewport.state"

local uiconfig      = require "widget.config"
local ImGui         = require "imgui"
local ImGuiInternal = require "imgui.internal"

local m = {}

local function screen_to_win(viewport, sx, sy)
    local offset = viewport.Pos
    local nsx, nsy = sx - offset.x, sy - offset.y
    if platform.os == "macos" then
        return nsx*viewport.DpiScale, nsy * viewport.DpiScale
    end
    return nsx, nsy
end

--x, y in scene view space
local function is_mouse_in_view(viewport)
    --sx, sy with dpi scale value in screen coordinate
    local sx, sy = ImGui.GetMousePos()
    --sdx, sdy after dpi transform window coordinate
    local sdx, sdy = screen_to_win(viewport, sx, sy)
    --dx, dy relative to scene viewrect
    local dx, dy = iviewport.cvt2scenept(sdx, sdy)
    return mu.pt2d_in_rect(dx, dy, iviewport.viewrect)
end

local last_vr = {x=0, y=0, w=0, h=0}

local function is_viewrect_different(lhs, rhs)
    return lhs.x ~= rhs.x or lhs.x ~= rhs.x or lhs.w ~= rhs.w or lhs.h ~= rhs.h
end

local handle_drop_file; do
    local VALID_DROPFILE_EXTENSIONS<const> = {
        [".prefab"] = true,
        [".glb"] = true,
        [".gltf"] = true,
        [".efk"] = true,
    }
    
    local function is_valid_drop_file(df)
        local ext = df:match "(%.[%w*?_%-]*)$"
        return VALID_DROPFILE_EXTENSIONS[ext:lower()]
    end

    local drag_file
    function handle_drop_file(viewport)
        if ImGui.IsMouseDragging(ImGui.MouseButton.Left) then
            if is_mouse_in_view(viewport) then
                if not drag_file then
                    local dropdata = ImGui.GetDragDropPayload()
                    if dropdata and is_valid_drop_file(dropdata) then
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
    end
end

local function handle_main_view(viewport)
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
        --NOTE: the coordinate return from DockBuilderGetCentralRect function is relative to full viewport
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
            iviewport.set_device_viewrect(dock_vr)
            world:dispatch_message {
                type        = "scene_viewrect",
                viewrect    = dock_vr,
            }
        end
    end
    ImGui.PopStyleVarEx(3)
    ImGui.End()
end

local function update_icons_dpi(viewport)
    if not icons.scale then
        icons.scale = platform.os == "macos" and 1.0 or viewport.DpiScale
    end
end

function m.show()
    local viewport = ImGui.GetMainViewport()
    update_icons_dpi(viewport)
    --drag file to view
    handle_drop_file(viewport)
    handle_main_view(viewport)
end

return m
local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr  = import_package "ant.asset"
local imgui     = require "imgui"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"

local m = {}

local status = {
    GizmoMode = "select",
    GizmoSpace = "worldspace"
}

local localSpace = {}
local defaultLight = { false }
function m.show()
    local icons = require "common.icons"(assetmgr)
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2])
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.ToolBarHeight)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowBorderSize, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.WindowBg, 0.25, 0.25, 0.25, 1)
    for _ in uiutils.imgui_windows("Controll", imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar", "NoMove", "NoDocking" }) do
        uiutils.imguiBeginToolbar()
        if uiutils.imguiToolbar(icons.ICON_SELECT, "Select", status.GizmoMode == "select") then
            status.GizmoMode = "select"
            world:pub { "GizmoMode", "select" }
        end
        imgui.cursor.SameLine()
        if uiutils.imguiToolbar(icons.ICON_MOVE, "Move", status.GizmoMode == "move") then
            status.GizmoMode = "move"
            world:pub { "GizmoMode", "move" }
        end
        imgui.cursor.SameLine()
        if uiutils.imguiToolbar(icons.ICON_ROTATE, "Rotate", status.GizmoMode == "rotate") then
            status.GizmoMode = "rotate"
            world:pub { "GizmoMode", "rotate" }
        end
        imgui.cursor.SameLine()
        if uiutils.imguiToolbar(icons.ICON_SCALE, "Scale", status.GizmoMode == "scale") then
            status.GizmoMode = "scale"
            world:pub { "GizmoMode", "scale" }
        end
        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("LocalSpace", localSpace) then
            world:pub { "GizmoMode", "localspace", localSpace[1]}
        end
        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("DefaultLight", defaultLight) then
            local action = defaultLight[1] and "enable_default_light" or "disable_default_light"
            world:pub { "Create", action }
        end
        uiutils.imguiEndToolbar()
    end
    imgui.windows.PopStyleColor()
    imgui.windows.PopStyleVar(2)
end

return m
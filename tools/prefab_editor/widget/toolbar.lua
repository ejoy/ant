local ecs   = ...
local world = ecs.world
local w     = world.w

local assetmgr  = import_package "ant.asset"
local imgui     = require "imgui"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local gizmo     = ecs.require "gizmo.gizmo"

local editor_setting = require "editor_setting"

local irq       = ecs.import.interface "ant.render|irenderqueue"

local m = {}

local status = {
    GizmoMode = "select",
    GizmoSpace = "worldspace"
}

local function is_select_camera()
    local e = gizmo.target_eid
    if e then
        w:sync("camera?in", e)
        return e.camera ~= nil
    end
end

local LAST_main_camera

local localSpace = {}
local defaultLight = { false }
local camera_speed = {0.1, speed=0.05, min=0.01, max=10}
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

        imgui.cursor.SameLine()
        imgui.cursor.PushItemWidth(64)
        camera_speed[1] = editor_setting.setting.camera.speed
        if imgui.widget.DragFloat("CameraSpeed", camera_speed) then
            world:pub{"camera_controller", "move_speed", camera_speed[1]}
            editor_setting.update_camera_setting(camera_speed[1])
            editor_setting.save()
        end
        imgui.cursor.PopItemWidth()

        if is_select_camera() then
            imgui.cursor.SameLine()
            local sv_camera = irq.camera "second_view"
            local mq_camera = irq.camera "main_queue"
            if LAST_main_camera == nil then
                LAST_main_camera = mq_camera
            end
            local as_mc = {sv_camera == mq_camera}
            if imgui.widget.Checkbox("As Main Camera", as_mc) then
                if as_mc[1] then
                    irq.set_camera("main_queue", sv_camera)
                    irq.set_visible("second_view", false)
                else
                    irq.set_camera("main_queue", LAST_main_camera)
                    LAST_main_camera = nil
                    irq.set_visible("second_view", true)
                end
            end
        end
        uiutils.imguiEndToolbar()
    end
    imgui.windows.PopStyleColor()
    imgui.windows.PopStyleVar(2)
end

return m
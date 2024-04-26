local ecs   = ...
local world = ecs.world
local w = world.w
local irq       = ecs.require "ant.render|renderqueue"
local gizmo     = ecs.require "gizmo.gizmo"
local ImGui     = require "imgui"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local editor_setting = require "editor_setting"

local m = {}

local status = {
    GizmoMode = "select",
    GizmoSpace = "worldspace"
}

local function is_select_camera()
    local eid = gizmo.target_eid
    if eid then
        local e <close> = world:entity(eid, "camera?in")
        return e.camera ~= nil
    end
end

local LAST_main_camera

local localSpace = {}
local defaultLight = { true }
local showground = { true }
local showterrain = { false }
local savehitch = { false }
local camera_speed = {0.1, speed=0.05, min=0.01, max=10}
local icons = require "common.icons"
local function mark_camera_changed(eid)
    local e <close> = world:entity(eid)
    w:extend(e, "camera_changed?out")
    e.camera_changed = true
    w:submit(e)
end
function m.show()
    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(viewport.WorkPos.x, viewport.WorkPos.y)
    ImGui.SetNextWindowSize(viewport.WorkSize.x, uiconfig.ToolBarHeight)
    ImGui.PushStyleVar(ImGui.StyleVar.WindowRounding, 0)
    ImGui.PushStyleVar(ImGui.StyleVar.WindowBorderSize, 0)
    ImGui.PushStyleColorImVec4(ImGui.Col.WindowBg, 0.25, 0.25, 0.25, 1)
    if ImGui.Begin("Controll", nil, ImGui.WindowFlags { "NoTitleBar", "NoResize", "NoScrollbar", "NoMove", "NoDocking" }) then
        uiutils.imguiBeginToolbar()
        if uiutils.imguiToolbar(icons.ICON_SELECT, "Select", status.GizmoMode == "select") then
            status.GizmoMode = "select"
            world:pub { "GizmoMode", "select" }
        end
        ImGui.SameLine()
        if uiutils.imguiToolbar(icons.ICON_MOVE, "Move", status.GizmoMode == "move") then
            status.GizmoMode = "move"
            world:pub { "GizmoMode", "move" }
        end
        ImGui.SameLine()
        if uiutils.imguiToolbar(icons.ICON_ROTATE, "Rotate", status.GizmoMode == "rotate") then
            status.GizmoMode = "rotate"
            world:pub { "GizmoMode", "rotate" }
        end
        ImGui.SameLine()
        if uiutils.imguiToolbar(icons.ICON_SCALE, "Scale", status.GizmoMode == "scale") then
            status.GizmoMode = "scale"
            world:pub { "GizmoMode", "scale" }
        end
        ImGui.SameLine()
        if ImGui.Checkbox("LocalSpace ", localSpace) then
            world:pub { "GizmoMode", "localspace", localSpace[1]}
        end
        ImGui.SameLine()
        if ImGui.Checkbox("DefaultLight ", defaultLight) then
            world:pub { "UpdateDefaultLight", defaultLight[1] }
        end
        ImGui.SameLine()
        if ImGui.Checkbox("Ground ", showground) then
            world:pub { "ShowGround", showground[1] }
        end
        ImGui.SameLine()
        if ImGui.Checkbox("Terrain ", showterrain) then
            world:pub { "ShowTerrain", showterrain[1] }
        end
        ImGui.SameLine()
        if ImGui.Checkbox("SaveHitch ", savehitch) then
            world:pub { "SaveHitch", savehitch[1] }
        end
        ImGui.SameLine()
        ImGui.PushItemWidth(72)
        camera_speed[1] = editor_setting.setting.camera.speed
        if ImGui.DragFloat("CameraSpeed", camera_speed) then
            world:pub{"camera_controller", "move_speed", camera_speed[1]}
            editor_setting.update_camera_setting(camera_speed[1])
            editor_setting.save()
        end
        ImGui.PopItemWidth()

        if is_select_camera() then
            ImGui.SameLine()
            local sv_camera = gizmo.target_eid -- irq.camera "second_view"
            local mq_camera = irq.camera "main_queue"
            if LAST_main_camera == nil then
                LAST_main_camera = mq_camera
            end
            local as_mc = {sv_camera == mq_camera}
            if ImGui.Checkbox("As Main Camera", as_mc) then
                if as_mc[1] then
                    irq.set_camera_from_queuename("main_queue", sv_camera)
                    world:pub {"LockCamera", sv_camera}
                    mark_camera_changed(sv_camera)
                    -- irq.set_visible("second_view", false)
                else
                    irq.set_camera_from_queuename("main_queue", LAST_main_camera)
                    -- irq.set_visible("second_view", true)
                    mark_camera_changed(LAST_main_camera)
                    LAST_main_camera = nil
                    world:pub {"LockCamera"}
                end
                world:pub {"camera", "change"}
            end
        end
        uiutils.imguiEndToolbar()
    end
    ImGui.PopStyleColor()
    ImGui.PopStyleVarEx(2)
    ImGui.End()
end

return m
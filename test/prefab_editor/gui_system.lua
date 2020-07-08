local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local imgui      = require "imgui"
local rhwi       = import_package 'ant.render'.hwi

local iom = world:interface "ant.objcontroller|obj_motion"

local scene = require "scene"

local function ONCE(t, s)
    if not s then return t end
end
local windiwsBegin = imgui.windows.Begin
local windiwsEnd = setmetatable({}, { __close = imgui.windows.End })
local function imgui_windows(...)
	windiwsBegin(...)
	return ONCE, windiwsEnd, nil, windiwsEnd
end

local function imgui_tooltip(text, wrap)
    if imgui.util.IsItemHovered() then
        imgui.widget.BeginTooltip()
        imgui.widget.TextWrapped(text, wrap or 200)
        imgui.widget.EndTooltip()
    end
end

local m = ecs.system 'gui_system'

local status = {
    GizmoMode = "select",
}

local function imguiBeginToolbar()
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.Button, 0, 0, 0, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.ButtonActive, 0, 0, 0, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.ButtonHovered, 0, 0, 0, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.ItemSpacing, 0, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.FramePadding, 0, 3)
end

local function imguiEndToolbar()
    imgui.windows.PopStyleVar(2)
    imgui.windows.PopStyleColor(3)
end

local function imguiToolbar(text, tooltip, active)
    if active then
        imgui.windows.PushStyleColor(imgui.enum.StyleCol.Text, 0.4, 0.4, 0.4, 1)
    else
        imgui.windows.PushStyleColor(imgui.enum.StyleCol.Text, 0.6, 0.6, 0.6, 1)
    end
    local r = imgui.widget.Button(text)
    imgui.windows.PopStyleColor()
    if tooltip then
        imgui_tooltip(tooltip)
    end
    return r
end
local PropertyWidgetWidth <const> = 320
local eventGizmo = world:sub {"Gizmo"}
local eventScene = world:sub {"Scene"}
local currentEID = {0, flags = imgui.flags.InputText{ "ReadOnly" }}
local gizmo
local cmd_queue
local currentPos = {0,0,0}
local currentRot = {0,0,0}
local currentScale = {1,1,1}
local currentName = {text = "noname"}
local testSlider = {1}
local localSpace = {}
local testText = {}
local SELECT <const> = 0
local MOVE <const> = 1
local ROTATE <const> = 2
local SCALE <const> = 3
local sourceEid = nil
local targetEid = nil
local function show_scene_node(node)
    local base_flags = imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((currentEID[1] == node.eid) and imgui.flags.TreeNode{"Selected"} or 0)
    local name = tostring(node.eid)--world[node.eid].name

    local function select_or_move(eid)
        if imgui.util.IsItemClicked() then
            currentEID[1] = eid
        end
        if imgui.widget.BeginDragDropSource() then
            imgui.widget.SetDragDropPayload("Reparent", eid)
            imgui.widget.EndDragDropSource()
        end
        if imgui.widget.BeginDragDropTarget() then
            local payload = imgui.widget.AcceptDragDropPayload("Reparent")
            if payload then
                sourceEid = tonumber(payload)
                targetEid = eid
            end
            imgui.widget.EndDragDropTarget()
        end
    end

    if #node.children == 0 then
        imgui.widget.TreeNode(name, base_flags | imgui.flags.TreeNode { "Leaf", "NoTreePushOnOpen" })
    else
        if imgui.widget.TreeNode(name, base_flags) then
            select_or_move(node.eid)
            for _, child in ipairs(node.children) do
                show_scene_node(child)
            end
            imgui.widget.TreePop()
            return
        end
    end
    select_or_move(node.eid)
end

function m:ui_update()
    imgui.windows.SetNextWindowPos(PropertyWidgetWidth, 0)
    for _ in imgui_windows("Controll", imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar" }) do
        imguiBeginToolbar()
        if imguiToolbar("🚫", "Select", status.GizmoMode == "select") then
            status.GizmoMode = "select"
            world:pub { "GizmoMode", "select" }
        end
        imgui.cursor.SameLine()
        if imguiToolbar("🔄", "Rotate", status.GizmoMode == "rotate") then
            status.GizmoMode = "rotate"
            world:pub { "GizmoMode", "rotate" }
        end
        imgui.cursor.SameLine()
        if imguiToolbar("🤚", "Move", status.GizmoMode == "move") then
            status.GizmoMode = "move"
            world:pub { "GizmoMode", "move" }
        end
        imgui.cursor.SameLine()
        if imguiToolbar("🔍", "Scale", status.GizmoMode == "scale") then
            status.GizmoMode = "scale"
            world:pub { "GizmoMode", "scale" }
        end
        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("LocalSpace", localSpace) then
            world:pub { "GizmoMode", "localspace", localSpace[1] }
        end
        imguiEndToolbar()
    end

    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(0, 0)
    imgui.windows.SetNextWindowSize(PropertyWidgetWidth, sh)

    for _ in imgui_windows("Scene", imgui.flags.Window { "NoResize", "NoScrollbar", "NoClosed" }) do
        sourceEid = nil
        targetEid = nil
        for _, child in ipairs(scene.children) do
            show_scene_node(child)
        end
        if sourceEid and targetEid then
            scene.set_parent(sourceEid, targetEid)
        end
    end
    
    imgui.windows.SetNextWindowPos(sw - PropertyWidgetWidth, 0)
    imgui.windows.SetNextWindowSize(PropertyWidgetWidth, sh)
    local oldPos = nil
    local oldRot = nil
    local oldScale = nil
    for _ in imgui_windows("Inspector", imgui.flags.Window { "NoResize", "NoScrollbar", "NoClosed" }) do
        
        imgui.widget.InputInt("EID", currentEID)
        if imgui.widget.InputText("Name", currentName) then
            world[currentEID[1]].name = tostring(currentName.text)
        end

        if imgui.widget.TreeNode("Transform", imgui.flags.TreeNode { "DefaultOpen" }) then
            if imgui.widget.InputFloat("Position", currentPos) then
                oldPos = math3d.totable(iom.get_position(gizmo.target_eid))
                gizmo:set_position(currentPos)
            end
            if imgui.widget.InputFloat("Rotate", currentRot) then
                oldRot = math3d.totable(iom.get_rotation(gizmo.target_eid))
                gizmo:set_rotation(currentRot)
            end
            if imgui.widget.InputFloat("Scale", currentScale) then
                oldScale = math3d.totable(iom.get_scale(gizmo.target_eid))
                gizmo:set_scale(currentScale)
            end

            imgui.widget.TreePop()
        end
        
    end

    if oldPos then
        cmd_queue:record({action = MOVE, eid = gizmo.target_eid, oldvalue = oldPos, newvalue = {currentPos[1], currentPos[2], currentPos[3]}})
        oldPos = nil
    elseif oldRot then
        cmd_queue:record({action = ROTATE, eid = gizmo.target_eid, oldvalue = oldRot, newvalue = {currentRot[1], currentRot[2], currentRot[3]}})
        oldRot = nil
    elseif oldScale then
        cmd_queue:record({action = SCALE, eid = gizmo.target_eid, oldvalue = oldScale, newvalue = {currentScale[1], currentScale[2], currentScale[3]}})
        oldScale = nil
    end

    for _, action, value1, value2 in eventGizmo:unpack() do
        if action == "update" or action == "ontarget" then
            if action == "ontarget" then
                currentEID[1] = gizmo.target_eid
                currentName.text = world[gizmo.target_eid].name
            end
            local s, r, t = math3d.srt(iom.srt(gizmo.target_eid))
            local Pos = math3d.totable(t)
            currentPos[1] = Pos[1]
            currentPos[2] = Pos[2]
            currentPos[3] = Pos[3]
    
            local Rot = math3d.totable(math3d.quat2euler(r))
            currentRot[1] = math.deg(Rot[1])
            currentRot[2] = math.deg(Rot[2])
            currentRot[3] = math.deg(Rot[3])
    
            local Scale = math3d.totable(s)
            currentScale[1] = Scale[1]
            currentScale[2] = Scale[2]
            currentScale[3] = Scale[3]
        elseif action == "create" then
            gizmo = value1
            cmd_queue = value2
        end
    end

    for _, action, eid in eventScene:unpack() do

    end
end

function m:data_changed()

end

local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local imgui      = require "imgui"
local rhwi       = import_package 'ant.render'.hwi

local iom = world:interface "ant.objcontroller|obj_motion"

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

local currentEID
local currentEIDPos = {0,0,0}
local currentEIDRot = {0,0,0}
local currentEIDScale = {1,1,1}
local localSpace = {}
function m:ui_update()
    imgui.windows.SetNextWindowPos(0, 0)
    for _ in imgui_windows("Controll", imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar" }) do
        imguiBeginToolbar()
        if imguiToolbar("🚫", "Select", status.GizmoMode == "select") then
            status.GizmoMode = "select"
            world:pub { "gizmo", "select" }
        end
        imgui.cursor.SameLine()
        if imguiToolbar("🔄", "Rotate", status.GizmoMode == "rotate") then
            status.GizmoMode = "rotate"
            world:pub { "gizmo", "rotate" }
        end
        imgui.cursor.SameLine()
        if imguiToolbar("🤚", "Move", status.GizmoMode == "move") then
            status.GizmoMode = "move"
            world:pub { "gizmo", "move" }
        end
        imgui.cursor.SameLine()
        if imguiToolbar("🔍", "Scale", status.GizmoMode == "scale") then
            status.GizmoMode = "scale"
            world:pub { "gizmo", "scale" }
        end
        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("LocalSpace", localSpace) then
            world:pub { "gizmo", "localspace", localSpace[1] }
        end
        imguiEndToolbar()
    end
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(sw - PropertyWidgetWidth, 0)
    imgui.windows.SetNextWindowSize(PropertyWidgetWidth, sh)

    

    for _, eid in eventGizmo:unpack() do
        currentEID = eid
        local s, r, t = math3d.srt(iom.srt(eid))
        local Pos = math3d.totable(t)
        currentEIDPos[1] = Pos[1]
        currentEIDPos[2] = Pos[2]
        currentEIDPos[3] = Pos[3]

        local Rot = math3d.totable(math3d.quat2euler(r))
        currentEIDRot[1] = math.deg(Rot[1])
        currentEIDRot[2] = math.deg(Rot[2])
        currentEIDRot[3] = math.deg(Rot[3])

        local Scale = math3d.totable(s)
        currentEIDScale[1] = Scale[1]
        currentEIDScale[2] = Scale[2]
        currentEIDScale[3] = Scale[3]
    end

    for _ in imgui_windows("Inspector", imgui.flags.Window { "NoResize", "NoScrollbar" }) do
        if imgui.widget.TreeNode("Transform", imgui.flags.TreeNode { "DefaultOpen" }) then
            imgui.widget.InputFloat("Position", currentEIDPos)
            imgui.widget.InputFloat("Rotate", currentEIDRot)
            imgui.widget.InputFloat("Scale", currentEIDScale)
            imgui.widget.TreePop()
        end
    end
end

function m:data_changed()

end

local ecs = ...
local world = ecs.world

local imgui      = require "imgui"
local rhwi       = import_package 'ant.render'.hwi

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

function m:ui_update()
    imgui.windows.SetNextWindowPos(0, 50)
    for _ in imgui_windows("Controll", imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar" }) do
        imguiBeginToolbar()
        if imguiToolbar("🚫", "Select", status.GizmoMode == "select") then
            status.GizmoMode = "select"
            world:pub { "gizmo", "select" }
        end
        if imguiToolbar("🔄", "Rotate", status.GizmoMode == "rotate") then
            status.GizmoMode = "rotate"
            world:pub { "gizmo", "rotate" }
        end
        if imguiToolbar("🤚", "Move", status.GizmoMode == "move") then
            status.GizmoMode = "move"
            world:pub { "gizmo", "move" }
        end
        if imguiToolbar("🔍", "Scale", status.GizmoMode == "scale") then
            status.GizmoMode = "scale"
            world:pub { "gizmo", "scale" }
        end
        imguiEndToolbar()
    end
end

function m:data_changed()

end

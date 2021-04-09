local ecs = ...
local world = ecs.world

local imgui      = require "imgui"
local rhwi      = import_package "ant.hwi"

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
    CameraMode = "disable",
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
        if imguiToolbar("🚫", "Disable", status.CameraMode == "disable") then
            status.CameraMode = "disable"
        end
        if imguiToolbar("🔄", "Rotate", status.CameraMode == "rotate") then
            status.CameraMode = "rotate"
        end
        if imguiToolbar("🤚", "Pan", status.CameraMode == "pan") then
            status.CameraMode = "pan"
        end
        if imguiToolbar("🔍", "Zoom", status.CameraMode == "zoom") then
            status.CameraMode = "zoom"
        end
        if imguiToolbar("🔴", "Reset Camera", true) then
            world:pub {"camera","reset"}
        end
        imguiEndToolbar()
    end
end

local eventMouse = world:sub {"mouse"}
local eventMouseWheel = world:sub {"mouse_wheel"}
local kRotationSpeed <const> = 1
local kZoomSpeed <const> = 1
local kPanSpeed <const> = 1
local kWheelSpeed <const> = 0.5
local lastMouse
local lastX, lastY

local function mouseRotate(dx, dy)
    world:pub { "camera", "rotate", dx*kRotationSpeed, dy*kRotationSpeed }
end

local function mouseZoom(_, dy)
    world:pub { "camera", "zoom", -dy*kZoomSpeed }
end

local function mousePan(dx, dy)
    world:pub { "camera", "pan", dx*kPanSpeed, dy*kPanSpeed }
end

local function mouseEvent(what, dx, dy)
    if status.CameraMode == "rotate" then
        if what == "LEFT" then
            mouseRotate(dx, dy)
        else
            mouseZoom(dx, dy)
        end
    elseif status.CameraMode == "pan" then
        if what == "LEFT" then
            mousePan(dx, dy)
        else
            mouseZoom(dx, dy)
        end
    elseif status.CameraMode == "zoom" then
        if what == "LEFT" then
            mouseZoom(dx, dy)
        end
    end
end

function m:data_changed()
    for _,what,state,x,y in eventMouse:unpack() do
        if state == "DOWN" then
            lastX, lastY = x, y
            lastMouse = what
        elseif state == "MOVE" and lastMouse == what then
            local dpiX, dpiY = rhwi.dpi()
            mouseEvent(what, (x - lastX) / dpiX, (y - lastY) / dpiY)
            lastX, lastY = x, y
        end
    end
    for _,delta in eventMouseWheel:unpack() do
        world:pub { "camera", "zoom", -delta*kWheelSpeed }
    end
end

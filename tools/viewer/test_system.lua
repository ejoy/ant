local ecs = ...
local world = ecs.world

local renderpkg  = import_package 'ant.render'
local imgui      = require "imgui"
local imgui_util = require "imgui_util"
local fs         = require 'filesystem'
local rhwi       = renderpkg.hwi

local m = ecs.system 'init_loader'

local function load_file(file)
    local f = assert(fs.open(fs.path(file), 'r'))
    local data = f:read 'a'
    f:close()
    return data
end

function m:init()
    renderpkg.components.create_grid_entity(world, "", nil, nil, nil, {
        srt = {
          s = {1,1,1,0},
          r = {0,0.92388,0,0.382683},
          t = {0,0,0,1},
        }
    })
    world:create_entity(load_file 'res/light_directional.txt')
    world:create_entity(load_file 'res/entity.txt')
end

function m:post_init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
end

local status = {
    CameraMode = "rotate",
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
        imgui_util.tooltip(tooltip)
    end
    return r
end

function m:ui_update()
    imgui.windows.SetNextWindowPos(0, 50)
    for _ in imgui_util.windows("Controll", imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar" }) do
        imguiBeginToolbar()
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

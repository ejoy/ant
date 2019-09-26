local ecs = ...
local world = ecs.world

ecs.import "ant.imguibase"

local imgui = require "imgui"
local fs = require "filesystem"

local steering_system = ecs.system "steering_system"

steering_system.singleton "message"
steering_system.depend "imgui_runtime_system"

local steeringTex
local mouset, mousex, mousey

function steering_system:init()
    local assetmgr = import_package "ant.asset".mgr
    local texloader = assetmgr.get_loader "texture"
    steeringTex = texloader(fs.path "/pkg/ant.modelviewer/res/steering.texture")
    
    local message = {}
    function message:mouse(x, y, what, state)
        if what ~= "LEFT" then
            return
        end
        if state == "MOVE" then
            mousex, mousey = x, y
        elseif state == "DOWN" then
            local w, _, wscale = imgui.getSize()
            mouset = x < w/wscale/2 and "l" or "r"
            mousex, mousey = x, y
        elseif state == "UP" then
            mouset = nil
        end
    end
    self.message.observers:add(message)
end

local wndflags = imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar", "NoInputs" }

local function testhit(t, w, h, size, cx, cy)
    if mouset ~= t then
        return
    end
    local mx, my = mousex, h - mousey
    local angle = math.atan(cy - my, cx - mx)
    local distance = math.sqrt((cy - my) * (cy - my) + (cx - mx) * (cx - mx))/size
    distance = math.min(distance, 1)
    return - distance*math.cos(angle), distance*math.sin(angle)
end

function steering_system:on_gui()
	local windows = imgui.windows
	local widget = imgui.widget
	local cursor = imgui.cursor
    local w, h, wscale, hscale = imgui.getSize()
    w = w / wscale
    h = h / hscale

    local size = 128
    
    windows.SetNextWindowPos(0,h/2)
    windows.SetNextWindowSize(w/2,h/2)
	windows.Begin("steering_left", wndflags)
    local cx, cy = size*1.5, h/2-size*1.5
	cursor.SetCursorPos(cx-size, cy-size)
    widget.Image(steeringTex.handle, size*2, size*2)
    local nx, ny = testhit("l", w, h, size, cx, cy)
    if nx then
        cursor.SetCursorPos(cx + nx*size - size*0.25, cy + ny*size - size*0.25)
        widget.Image(steeringTex.handle, size*0.5, size*0.5)
    end
	windows.End()

    windows.SetNextWindowPos(w/2,h/2)
    windows.SetNextWindowSize(w/2,h/2)
	windows.Begin("steering_right", wndflags)
    local cx, cy = w/2-size*1.5, h/2-size*1.5
	cursor.SetCursorPos(cx-size, cy-size)
	widget.Image(steeringTex.handle, size*2, size*2)
    local nx, ny = testhit("r", w, h, size, cx, cy)
    if nx then
        cursor.SetCursorPos(cx + nx*size - size*0.25, cy + ny*size - size*0.25)
        widget.Image(steeringTex.handle, size*0.5, size*0.5)
    end
	windows.End()
end

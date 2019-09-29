local ecs = ...
local world = ecs.world

ecs.import "ant.imguibase"

local imgui = require "imgui"
local fs = require "filesystem"

local steering_system = ecs.system "steering_system"

steering_system.singleton "message"
steering_system.depend "imgui_runtime_system"

local steeringTex
local touch = {
    l = {},
    r = {},
}

function steering_system:init()
    local assetmgr = import_package "ant.asset".mgr
    local texloader = assetmgr.get_loader "texture"
    steeringTex = texloader(fs.path "/pkg/ant.modelviewer/res/steering.texture")
    
    local message = {}
    function message:mouse(x, y, what, state)
        if what ~= "LEFT" then
            return
        end
        if state == "DOWN" then
            local w, _, wscale = imgui.getSize()
            if x < w/wscale/2 then
                touch.l.enable = true
            else
                touch.r.enable = true
            end
        end
        
        local s
        if touch.l.enable then
            s = touch.l
        elseif touch.r.enable then
            s = touch.r
        else
            return
        end

        if state == "UP" then
            s.enable = nil
        end
        s.x, s.y = x, y
        s.state = state
    end
    self.message.observers:add(message)
end

local wndflags = imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar", "NoInputs" }

local function testhit(t, w, h, size, cx, cy)
    if not touch[t].enable then
        return
    end
    local mx, my = touch[t].x, h - touch[t].y
    local angle = math.atan(my - cy, mx - cx)
    local distance = math.sqrt((cy - my) * (cy - my) + (cx - mx) * (cx - mx))/size
    distance = math.min(distance, 1)
    return distance*math.cos(angle), -distance*math.sin(angle)
end

local function hitpos(cx, cy, size, nx, ny)
    return cx + nx*size - size*0.25, cy + ny*size - size*0.25
end

function steering_system:on_gui()
    local windows = imgui.windows
    local widget = imgui.widget
    local cursor = imgui.cursor
    local mq = world.args.mq
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
        cursor.SetCursorPos(hitpos(cx, cy, size, nx, ny))
        widget.Image(steeringTex.handle, size*0.5, size*0.5)
        mq:push("steering", "W", -ny)
        mq:push("steering", "D", nx)
    end
    windows.End()

    windows.SetNextWindowPos(w/2,h/2)
    windows.SetNextWindowSize(w/2,h/2)
    windows.Begin("steering_right", wndflags)
    local cx, cy = w/2-size*1.5, h/2-size*1.5
    cursor.SetCursorPos(cx-size, cy-size)
    widget.Image(steeringTex.handle, size*2, size*2)
    local nx, ny = testhit("r", w, h, size, cx+w/2, cy)
    if nx then
        local x, y = hitpos(cx, cy, size, nx, ny)
        cursor.SetCursorPos(x, y)
        widget.Image(steeringTex.handle, size*0.5, size*0.5)
        mq:push("mouse", x, y, "RIGHT", touch.r.press and "MOVE" or "DOWN")
        touch.r.press = true
    end
    windows.End()

    if touch.l.state == "UP" then
        mq:push("steering", "W", 0)
        mq:push("steering", "D", 0)
        touch.l.state = nil
    end
    if touch.r.state == "UP" then
        mq:push("mouse", 0, 0, "RIGHT", "UP")
        touch.r.state = nil
        touch.r.press = nil
    end
end

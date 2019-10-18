local ecs = ...
local world = ecs.world

ecs.import "ant.imguibase"

local imgui = require "imgui"
local fs = require "filesystem"
local platform = require "platform"

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
    steeringTex = texloader(fs.path "/pkg/unity_viking/Assets/textures/steering.texture")

    local message = {}
    local function event_touch(x, y, id, state)
        local w, _, wscale,hscale = imgui.getSize()
        x,y=x/wscale,y/hscale
        if state == "DOWN" then
            if x < w/2 then
                touch.l.enable = id
            else
                touch.r.enable = id
            end
        end

        local s
        if touch.l.enable == id then
            s = touch.l
        elseif touch.r.enable == id then
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

    if platform.OS == "iOS" then
        function message:touch(x, y, id, state)
            event_touch(x, y, id, state)
        end
    else
        function message:mouse(x, y, what, state)
            if what ~= "LEFT" then
                return
            end
            event_touch(x, y, true, state)
        end
    end
    self.message.observers:add(message)
end

local wndflags = imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar", "NoInputs" }

local function testhit(t, w, h, size, cx, cy)
    if not touch[t].enable then
        return
    end
    local mx, my = touch[t].x, touch[t].y - h/2
    local angle = math.atan(my - cy, mx - cx)
    local distance = math.sqrt((cy - my) * (cy - my) + (cx - mx) * (cx - mx))/size
    distance = math.min(distance, 1)
    return distance*math.cos(angle), distance*math.sin(angle)
end

local function hitpos(cx, cy, size, nx, ny)
    return cx + nx*size - size*0.25, cy + ny*size - size*0.25
end

function steering_system:on_gui()
    local windows = imgui.windows
    local widget = imgui.widget
    local cursor = imgui.cursor
    local mq = world.args.mq
    local w, h = imgui.getSize()

    local size = w / 8
    
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

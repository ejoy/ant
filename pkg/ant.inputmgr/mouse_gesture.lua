local ltask = require "ltask"

local MouseLeft <const> = 1
local MouseDown <const> = 1
local MouseMove <const> = 2
local MouseUp <const> = 3

local function start_timer(timeout, f)
    local t = {}
    ltask.timeout(timeout / 10, function ()
        if not t.stop then
            f()
        end
    end)
    return t
end

local function stop_timer(t)
    t.stop = true
end

return function (ev)
    local lastX
    local lastY
    local downX
    local downY
    local inLongPress
    local alwaysInTapRegion
    local longPressTimer = {}
    local touchSlopSquare <const> = 11 * 11
    local longPressTimeout <const> = 400

    local function dispatch_long_press()
        inLongPress = true
        ev.gesture("long_press", {
            x = downX,
            y = downY,
        })
    end

    local function mouse_down(x, y)
        lastX = x
        lastY = y
        downX = x
        downY = y
        inLongPress = false
        alwaysInTapRegion = true
        stop_timer(longPressTimer)
        longPressTimer = start_timer(longPressTimeout, dispatch_long_press)
    end
    local function mouse_move(x, y)
        if inLongPress then
            return
        end
        local scrollX = x - lastX
        local scrollY = y - lastY
        local deltaX = x - downX
        local deltaY = y - downY
        if alwaysInTapRegion then
            local distance = (deltaX * deltaX) + (deltaY * deltaY)
            if distance > touchSlopSquare then
                ev.gesture("pan", {
                    x = x,
                    y = y,
                    dx = scrollX,
                    dy = scrollY,
                    vx = deltaX,
                    vy = deltaY,
                })
                lastX = x
                lastY = y
                alwaysInTapRegion = false
                stop_timer(longPressTimer)
            end
        elseif math.abs(scrollX) >= 1 or math.abs(scrollY) >= 1 then
            ev.gesture("pan", {
                x = x,
                y = y,
                dx = scrollX,
                dy = scrollY,
                vx = deltaX,
                vy = deltaY,
            })
            lastX = x
            lastY = y
        end
    end
    local function mouse_up(x, y)
        if inLongPress then
            inLongPress = false
        elseif alwaysInTapRegion then
            ev.gesture("tap", {
                x = x,
                y = y,
            })
        end
        stop_timer(longPressTimer)
    end
    function ev.mouse_wheel(x, y, delta)
        ev.gesture("pinch", {
            x = x,
            y = y,
            velocity = delta,
        })
    end
    function ev.mouse(x, y, what, state)
        if what ~= MouseLeft then
            return
        end
        if state == MouseDown then
            mouse_down(x, y)
            return
        end
        if state == MouseMove then
            mouse_move(x, y)
            return
        end
        if state == MouseUp then
            mouse_up(x, y)
            return
        end
    end
end

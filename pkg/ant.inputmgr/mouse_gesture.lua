local ltask = require "ltask"

local MOUSE_LEFT <const> = 1
local MOUSE_MIDDLE <const> = 2
local MOUSE_RIGHT <const> = 3

local MOUSE_DOWN <const> = 1
local MOUSE_MOVE <const> = 2
local MOUSE_UP <const> = 3

local TOUCH_BEGAN <const> = 1
local TOUCH_MOVED <const> = 2
local TOUCH_ENDED <const> = 3
local TOUCH_CANCELLED <const> = 4

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
    local inScrolling
    local alwaysInTapRegion
    local longPressTimer = {}
    local touchSlopSquare <const> = 11 * 11
    local longPressTimeout <const> = 400

    local function dispatch_longpress()
        inLongPress = true
        ev.gesture("longpress", {
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
        inScrolling = false
        alwaysInTapRegion = true
        stop_timer(longPressTimer)
        longPressTimer = start_timer(longPressTimeout, dispatch_longpress)
    end
    local function mouse_move(x, y)
        if inLongPress then
            return
        end
        if not lastX then
            return
        end
        local scrollX = x - lastX
        local scrollY = y - lastY
        local deltaX = x - downX
        local deltaY = y - downY
        if alwaysInTapRegion then
            local distance = (deltaX * deltaX) + (deltaY * deltaY)
            if distance > touchSlopSquare then
                if not inScrolling then
                    inScrolling = true
                    ev.gesture("pan", {
                        state = "began",
                        x = x,
                        y = y,
                        dx = 0,
                        dy = 0,
                    })
                end
                ev.gesture("pan", {
                    state = "changed",
                    x = x,
                    y = y,
                    dx = scrollX,
                    dy = scrollY,
                })
                lastX = x
                lastY = y
                alwaysInTapRegion = false
                stop_timer(longPressTimer)
            end
        elseif math.abs(scrollX) >= 1 or math.abs(scrollY) >= 1 then
            if not inScrolling then
                inScrolling = true
                ev.gesture("pan", {
                    state = "began",
                    x = x,
                    y = y,
                    dx = 0,
                    dy = 0,
                })
            end
            ev.gesture("pan", {
                state = "changed",
                x = x,
                y = y,
                dx = scrollX,
                dy = scrollY,
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
        elseif inScrolling then
            inScrolling = false
            local scrollX = x - lastX
            local scrollY = y - lastY
            ev.gesture("pan", {
                state = "ended",
                x = x,
                y = y,
                dx = scrollX,
                dy = scrollY,
            })
        end
        lastX = nil
        lastY = nil
        stop_timer(longPressTimer)
    end
    function ev.mousewheel(x, y, delta)
        ev.gesture("pinch", {
            x = x,
            y = y,
            velocity = delta,
        })
    end
    function ev.mouse(x, y, what, state)
        ev.mouse_event(x, y, what, state)
        if what ~= MOUSE_LEFT then
            return
        end
        if state == MOUSE_DOWN then
            ev.touch(what, TOUCH_BEGAN, x, y)
            mouse_down(x, y)
            return
        end
        if state == MOUSE_MOVE then
            ev.touch(what, TOUCH_MOVED, x, y)
            mouse_move(x, y)
            return
        end
        if state == MOUSE_UP then
            mouse_up(x, y)
            ev.touch(what, TOUCH_ENDED, x, y)
            return
        end
    end
end

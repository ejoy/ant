local ltask = require "ltask"
local time = require "bee.time"

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

local function get_time()
    local _, now = ltask.now()
    return now / 100
end

return function (ev)
    local currentTime = 0
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
        ltask.call(ltask.self(), "msg", {
            type = "gesture",
            what = "longpress",
            x = downX,
            y = downY,
            state = "began",
            timestamp = time.monotonic(),
        })
        inLongPress = true
    end

    local function mouse_down(m)
        lastX = m.x
        lastY = m.y
        downX = m.x
        downY = m.y
        inLongPress = false
        inScrolling = nil
        alwaysInTapRegion = true
        stop_timer(longPressTimer)
        longPressTimer = start_timer(longPressTimeout, dispatch_longpress)
    end
    local function mouse_move(m)
        if inLongPress then
            ev.gesture {
                type = "gesture",
                what = "longpress",
                x = m.x,
                y = m.y,
                state = "changed",
                timestamp = m.timestamp,
            }
            return
        end
        if not lastX then
            return
        end
        local scrollX = m.x - lastX
        local scrollY = m.y - lastY
        local deltaX = m.x - downX
        local deltaY = m.y - downY
        if alwaysInTapRegion then
            local distance = (deltaX * deltaX) + (deltaY * deltaY)
            if distance > touchSlopSquare then
                if not inScrolling then
                    inScrolling = get_time()
                    ev.gesture {
                        type = "gesture",
                        what = "pan",
                        state = "began",
                        x = m.x,
                        y = m.y,
                        velocity_x = 0,
                        velocity_y = 0,
                        timestamp = m.timestamp,
                    }
                end
                ev.gesture {
                    type = "gesture",
                    what = "pan",
                    state = "changed",
                    x = m.x,
                    y = m.y,
                    velocity_x = scrollX / inScrolling,
                    velocity_y = scrollY / inScrolling,
                    timestamp = m.timestamp,
                }
                lastX = m.x
                lastY = m.y
                alwaysInTapRegion = false
                stop_timer(longPressTimer)
            end
        elseif math.abs(scrollX) >= 1 or math.abs(scrollY) >= 1 then
            if not inScrolling then
                inScrolling = get_time()
                ev.gesture {
                    type = "gesture",
                    what = "pan",
                    state = "began",
                    x = m.x,
                    y = m.y,
                    velocity_x = 0,
                    velocity_y = 0,
                    timestamp = m.timestamp,
                }
            end
            ev.gesture {
                type = "gesture",
                what = "pan",
                state = "changed",
                x = m.x,
                y = m.y,
                velocity_x = scrollX / inScrolling,
                velocity_y = scrollY / inScrolling,
                timestamp = m.timestamp,
            }
            lastX = m.x
            lastY = m.y
        end
    end
    local function mouse_up(m)
        if inLongPress then
            inLongPress = false
            ev.gesture {
                type = "gesture",
                what = "longpress",
                x = m.x,
                y = m.y,
                state = "ended",
                timestamp = m.timestamp,
            }
        elseif alwaysInTapRegion then
            ev.gesture {
                type = "gesture",
                what = "tap",
                x = m.x,
                y = m.y,
                timestamp = m.timestamp,
            }
        elseif inScrolling then
            local scrollX = m.x - lastX
            local scrollY = m.y - lastY
            ev.gesture {
                type = "gesture",
                what = "pan",
                state = "ended",
                x = m.x,
                y = m.y,
                velocity_x = scrollX / inScrolling,
                velocity_y = scrollY / inScrolling,
                timestamp = m.timestamp,
            }
            inScrolling = nil
        end
        lastX = nil
        lastY = nil
        stop_timer(longPressTimer)
    end
    function ev.mousewheel(m)
        ev.gesture {
            type = "gesture",
            what = "pinch",
            x = m.x,
            y = m.y,
            velocity = m.delta,
            timestamp = m.timestamp,
        }
    end
    function ev.mouse(m)
        ev.mouse_event(m)
        if m.what ~= MOUSE_LEFT then
            return
        end
        if m.state == MOUSE_DOWN then
            ev.touch {
                type = "touch",
                id = 1,
                state = TOUCH_BEGAN,
                x = m.x,
                y = m.y,
                timestamp = m.timestamp,
            }
            mouse_down(m)
            return
        end
        if m.state == MOUSE_MOVE then
            ev.touch {
                type = "touch",
                id = 1,
                state = TOUCH_MOVED,
                x = m.x,
                y = m.y,
                timestamp = m.timestamp,
            }
            mouse_move(m)
            return
        end
        if m.state == MOUSE_UP then
            mouse_up(m)
            ev.touch {
                type = "touch",
                id = 1,
                state = TOUCH_ENDED,
                x = m.x,
                y = m.y,
                timestamp = m.timestamp,
            }
            return
        end
    end
end

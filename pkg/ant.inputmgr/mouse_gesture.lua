local ltask = require "ltask"
local time = require "bee.time"

local Mouse2Touch <const> = {
    LEFT = 1,
    MIDDLE = 2,
    RIGHT = 3,
}

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

return function (dispatch)
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
        ltask.call(ltask.self(), "msg", {{
            type = "gesture",
            what = "longpress",
            x = downX,
            y = downY,
            state = "began",
            timestamp = time.monotonic(),
        }})
        inLongPress = true
    end

    local function mouse_down(e)
        lastX = e.x
        lastY = e.y
        downX = e.x
        downY = e.y
        inLongPress = false
        inScrolling = nil
        alwaysInTapRegion = true
        stop_timer(longPressTimer)
        longPressTimer = start_timer(longPressTimeout, dispatch_longpress)
    end
    local function mouse_move(e)
        if inLongPress then
            dispatch {
                type = "gesture",
                what = "longpress",
                x = e.x,
                y = e.y,
                state = "changed",
                timestamp = e.timestamp,
            }
            return
        end
        if not lastX then
            return
        end
        local scrollX = e.x - lastX
        local scrollY = e.y - lastY
        local deltaX = e.x - downX
        local deltaY = e.y - downY
        if alwaysInTapRegion then
            local distance = (deltaX * deltaX) + (deltaY * deltaY)
            if distance > touchSlopSquare then
                if not inScrolling then
                    inScrolling = get_time()
                    dispatch {
                        type = "gesture",
                        what = "pan",
                        state = "began",
                        x = e.x,
                        y = e.y,
                        velocity_x = 0,
                        velocity_y = 0,
                        timestamp = e.timestamp,
                    }
                end
                dispatch {
                    type = "gesture",
                    what = "pan",
                    state = "changed",
                    x = e.x,
                    y = e.y,
                    velocity_x = scrollX / inScrolling,
                    velocity_y = scrollY / inScrolling,
                    timestamp = e.timestamp,
                }
                lastX = e.x
                lastY = e.y
                alwaysInTapRegion = false
                stop_timer(longPressTimer)
            end
        elseif math.abs(scrollX) >= 1 or math.abs(scrollY) >= 1 then
            if not inScrolling then
                inScrolling = get_time()
                dispatch {
                    type = "gesture",
                    what = "pan",
                    state = "began",
                    x = e.x,
                    y = e.y,
                    velocity_x = 0,
                    velocity_y = 0,
                    timestamp = e.timestamp,
                }
            end
            dispatch {
                type = "gesture",
                what = "pan",
                state = "changed",
                x = e.x,
                y = e.y,
                velocity_x = scrollX / inScrolling,
                velocity_y = scrollY / inScrolling,
                timestamp = e.timestamp,
            }
            lastX = e.x
            lastY = e.y
        end
    end
    local function mouse_up(e)
        if inLongPress then
            inLongPress = false
            dispatch {
                type = "gesture",
                what = "longpress",
                x = e.x,
                y = e.y,
                state = "ended",
                timestamp = e.timestamp,
            }
        elseif alwaysInTapRegion then
            dispatch {
                type = "gesture",
                what = "tap",
                x = e.x,
                y = e.y,
                timestamp = e.timestamp,
            }
        elseif inScrolling then
            local scrollX = e.x - lastX
            local scrollY = e.y - lastY
            dispatch {
                type = "gesture",
                what = "pan",
                state = "ended",
                x = e.x,
                y = e.y,
                velocity_x = scrollX / inScrolling,
                velocity_y = scrollY / inScrolling,
                timestamp = e.timestamp,
            }
            inScrolling = nil
        end
        lastX = nil
        lastY = nil
        stop_timer(longPressTimer)
    end
    local m = {}
    function m.mousewheel(e)
        dispatch {
            type = "gesture",
            what = "pinch",
            x = e.x,
            y = e.y,
            velocity = e.delta,
            timestamp = e.timestamp,
        }
    end
    function m.mouse(e)
        if e.state == "DOWN" then
            dispatch {
                type = "touch",
                state = "began",
                id = Mouse2Touch[e.what],
                x = e.x,
                y = e.y,
                timestamp = e.timestamp,
            }
        elseif e.state == "MOVE" then
            dispatch {
                type = "touch",
                state = "moved",
                id = Mouse2Touch[e.what],
                x = e.x,
                y = e.y,
                timestamp = e.timestamp,
            }
        elseif e.state == "UP" then
            dispatch {
                type = "touch",
                state = "ended",
                id = Mouse2Touch[e.what],
                x = e.x,
                y = e.y,
                timestamp = e.timestamp,
            }
        end
        if e.what == "LEFT" then
            if e.state == "DOWN" then
                mouse_down(e)
            elseif e.state == "MOVE" then
                mouse_move(e)
            elseif e.state == "UP" then
                mouse_up(e)
            end
        end
    end
    return m
end

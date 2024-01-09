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

return function (world)
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
            world:dispatch_message {
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
                    world:dispatch_message {
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
                world:dispatch_message {
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
                world:dispatch_message {
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
            world:dispatch_message {
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
            world:dispatch_message {
                type = "gesture",
                what = "longpress",
                x = e.x,
                y = e.y,
                state = "ended",
                timestamp = e.timestamp,
            }
        elseif alwaysInTapRegion then
            world:dispatch_message {
                type = "gesture",
                what = "tap",
                x = e.x,
                y = e.y,
                timestamp = e.timestamp,
            }
        elseif inScrolling then
            local scrollX = e.x - lastX
            local scrollY = e.y - lastY
            world:dispatch_message {
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
        world:dispatch_message {
            type = "gesture",
            what = "pinch",
            x = e.x,
            y = e.y,
            velocity = e.delta,
            timestamp = e.timestamp,
        }
    end
    function m.mousemove(e)
        if e.what.LEFT then
            world:dispatch_message {
                type = "touch",
                state = "moved",
                id = Mouse2Touch.LEFT,
                x = e.x,
                y = e.y,
                timestamp = e.timestamp,
            }
            mouse_move(e)
        end
        if e.what.MIDDLE then
            world:dispatch_message {
                type = "touch",
                state = "moved",
                id = Mouse2Touch.MIDDLE,
                x = e.x,
                y = e.y,
                timestamp = e.timestamp,
            }
        end
        if e.what.RIGHT then
            world:dispatch_message {
                type = "touch",
                state = "moved",
                id = Mouse2Touch.RIGHT,
                x = e.x,
                y = e.y,
                timestamp = e.timestamp,
            }
        end
    end
    function m.mouseclick(e)
        if e.state == "DOWN" then
            world:dispatch_message {
                type = "touch",
                state = "began",
                id = Mouse2Touch[e.what],
                x = e.x,
                y = e.y,
                timestamp = e.timestamp,
            }
        elseif e.state == "UP" then
            world:dispatch_message {
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
            elseif e.state == "UP" then
                mouse_up(e)
            end
        end
    end
    return m
end

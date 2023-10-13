local platform = require "bee.platform"
local ltask = require "ltask"
local ServiceRmlui; do
    ltask.fork(function ()
        ServiceRmlui = ltask.queryservice "ant.rmlui|rmlui"
    end)
end

local function create(world, type)
    local keymap = require(type.."_keymap")
    local ev = {}
    local active_gesture = {}
    local function rmlui_sendmsg(...)
        return ltask.call(ServiceRmlui, ...)
    end
    local function world_sendmsg(...)
        world:pub {...}
    end
    function ev.gesture(what, data)
        local active = active_gesture[what]
        if active then
            if active == "world" then
                world_sendmsg("gesture", what, data)
            else
                rmlui_sendmsg("gesture", what, data)
            end
            if data.state == "ended" then
                active_gesture[what] = nil
            end
        elseif data.state == "began" then
            if ServiceRmlui then
                if rmlui_sendmsg("gesture", what, data) then
                    active_gesture[what] = "rmlui"
                    return
                end
            end
            world_sendmsg("gesture", what, data)
            active_gesture[what] = "world"
        else
            assert(data.state == nil)
            if ServiceRmlui then
                if rmlui_sendmsg("gesture", what, data) then
                    return
                end
            end
            world_sendmsg("gesture", what, data)
        end
    end
    function ev.touch(...)
        if ServiceRmlui then
            ltask.call(ServiceRmlui, "touch", ...)
        end
    end
    function ev.keyboard(key, press, state)
        world:pub {"keyboard", keymap[key], press, {
            CTRL	= (state & 0x01) ~= 0,
            SHIFT	= (state & 0x02) ~= 0,
            ALT		= (state & 0x04) ~= 0,
            SYS		= (state & 0x08) ~= 0,
        }}
    end
    function ev.size(w, h)
        world:pub {"resize", w, h}
    end
    if platform.os ~= "ios" and platform.os ~= "android" then
        if world.args.ecs.enable_mouse then
            local mouse_what  = { 'LEFT', 'MIDDLE', 'RIGHT' }
            local mouse_state = { 'DOWN', 'MOVE', 'UP' }
            function ev.mouse_event(x, y, what, state)
                world:pub {"mouse", mouse_what[what] or "UNKNOWN", mouse_state[state] or "UNKNOWN", x, y}
            end
        else
            function ev.mouse_event()
            end
        end
        require "mouse_gesture" (ev)
    end
    return ev
end

return {
    create = create,
}

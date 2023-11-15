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
    function ev.gesture(m)
        local active = active_gesture[m.what]
        if active then
            if active == "world" then
                world_sendmsg("gesture", m.what, m)
            else
                rmlui_sendmsg("gesture", m)
            end
            if m.state == "ended" then
                active_gesture[m.what] = nil
            end
        elseif m.state == "began" then
            if ServiceRmlui then
                if rmlui_sendmsg("gesture", m) then
                    active_gesture[m.what] = "rmlui"
                    return
                end
            end
            world_sendmsg("gesture", m.what, m)
            active_gesture[m.what] = "world"
        else
            -- assert(m.state == nil)
            if ServiceRmlui then
                if rmlui_sendmsg("gesture", m) then
                    return
                end
            end
            world_sendmsg("gesture", m.what, m)
        end
    end
    function ev.touch(m)
        if ServiceRmlui then
            ltask.call(ServiceRmlui, "touch", m)
        end
    end
    function ev.keyboard(m)
        world:pub {"keyboard", keymap[m.key], m.press, {
            CTRL	= (m.state & 0x01) ~= 0,
            SHIFT	= (m.state & 0x02) ~= 0,
            ALT		= (m.state & 0x04) ~= 0,
            SYS		= (m.state & 0x08) ~= 0,
        }}
    end
    function ev.size(m)
        world:pub {"resize", m.w, m.h}
    end
    if platform.os ~= "ios" and platform.os ~= "android" then
        if world.args.ecs.enable_mouse then
            local mouse_what  = { 'LEFT', 'MIDDLE', 'RIGHT' }
            local mouse_state = { 'DOWN', 'MOVE', 'UP' }
            function ev.mouse_event(m)
                world:pub {"mouse", mouse_what[m.what] or "UNKNOWN", mouse_state[m.state] or "UNKNOWN", m.x, m.y}
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

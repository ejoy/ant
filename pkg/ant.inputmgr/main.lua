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
    function ev.gesture(m)
        local active = active_gesture[m.what]
        if active then
            if active == "world" then
                world:pub { "gesture", m.what, m }
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
            world:pub { "gesture", m.what, m }
            active_gesture[m.what] = "world"
        else
            -- assert(m.state == nil)
            if ServiceRmlui then
                if rmlui_sendmsg("gesture", m) then
                    return
                end
            end
            world:pub { "gesture", m.what, m }
        end
    end
    function ev.touch(m)
        if ServiceRmlui then
            if rmlui_sendmsg("touch", m) then
                return
            end
        end
        world:pub { "touch", m }
    end
    function ev.keyboard(m)
        world:pub {"keyboard", keymap[m.key], m.press, m.state}
    end
    function ev.size(m)
        local fb = world.args.framebuffer
        fb.width, fb.height = m.w, m.h
        log.info("resize:", fb.width, fb.height)
        world:pub {"resize", m.w, m.h}
    end
    if platform.os ~= "ios" and platform.os ~= "android" then
        if world.args.ecs.enable_mouse then
            function ev.mouse_event(m)
                world:pub {"mouse", m.what, m.state, m.x, m.y}
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

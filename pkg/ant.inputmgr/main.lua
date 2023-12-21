local platform = require "bee.platform"
local ltask = require "ltask"
local imgui = require "imgui"

local keymap = {}

for name, index in pairs(imgui.enum.Key) do
    keymap[index] = name
end

local ServiceRmlui; do
    ltask.fork(function ()
        ServiceRmlui = ltask.queryservice "ant.rmlui|rmlui"
    end)
end

local function create(world)
    local active_gesture = {}
    local function rmlui_sendmsg(...)
        return ltask.call(ServiceRmlui, ...)
    end
    local m = {}
    local event = {}
    function event.gesture(e)
        local active = active_gesture[e.what]
        if active then
            if active == "world" then
                world:pub { "gesture", e.what, e }
            else
                rmlui_sendmsg("gesture", e)
            end
            if e.state == "ended" then
                active_gesture[e.what] = nil
            end
        elseif e.state == "began" then
            if ServiceRmlui then
                if rmlui_sendmsg("gesture", e) then
                    active_gesture[e.what] = "rmlui"
                    return
                end
            end
            world:pub { "gesture", e.what, e }
            active_gesture[e.what] = "world"
        else
            -- assert(m.state == nil)
            if ServiceRmlui then
                if rmlui_sendmsg("gesture", e) then
                    return
                end
            end
            world:pub { "gesture", e.what, e }
        end
    end
    function event.touch(e)
        if ServiceRmlui then
            if rmlui_sendmsg("touch", e) then
                return
            end
        end
        world:pub { "touch", e }
    end
    function event.keyboard(e)
        world:pub {"keyboard", keymap[e.key], e.press, e.state}
    end
    function event.dropfiles(...)
        world:pub {"dropfiles", ...}
    end
    function event.inputchar(...)
        world:pub {"inputchar", ...}
    end
    function event.focus(...)
        world:pub {"focus", ...}
    end
    function event.size(e)
        if not __ANT_EDITOR__ then
            rmlui_sendmsg("set_viewrect", {
                x = 0,
                y = 0,
                w = e.w,
                h = e.h,
                ratio = world.args.scene.ratio,
            })
        end
        local fb = world.args.scene
        fb.width, fb.height = e.w, e.h
        world:pub {"resize", e.w, e.h}
    end
    function m.set_viewrect(vr)
        rmlui_sendmsg("set_viewrect", {
            x = vr.x,
            y = vr.y,
            w = vr.w,
            h = vr.h,
            ratio = world.args.scene.ratio,
        })
        world:pub{"scene_viewrect_changed", vr}
    end
    function m.dispatch(e)
        local f = assert(event[e.type], e.type)
        f(e)
    end
    if platform.os ~= "ios" and platform.os ~= "android" then
        local mg = require "mouse_gesture" (m.dispatch)
        event.mousewheel = mg.mousewheel
        if world.args.ecs.enable_mouse then
            function event.mouse(e)
                world:pub {"mouse", e.what, e.state, e.x, e.y}
                mg.mouse(e)
            end
        else
            event.mouse = mg.mouse
        end
    end
    return m
end

return {
    create = create,
}

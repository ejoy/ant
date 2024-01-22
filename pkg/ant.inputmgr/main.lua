local platform = require "bee.platform"
local ltask = require "ltask"
local ImGui = require "imgui"

local keymap = {}

for name, index in pairs(ImGui.Enum.Key) do
    keymap[index] = name
end

local ServiceRmlui; do
    ltask.fork(function ()
        ServiceRmlui = ltask.queryservice "ant.rmlui|rmlui"
    end)
end

local function create(world)
    local function rmlui_sendmsg(...)
        if ServiceRmlui then
            return ltask.call(ServiceRmlui, ...)
        end
    end
    local event = {}
    function event.gesture(e)
        if rmlui_sendmsg("gesture", e) then
            return
        end
        world:pub { "gesture", e.what, e }
    end
    function event.touch(e)
        if rmlui_sendmsg("touch", e) then
            return
        end
        world:pub { "touch", e }
    end
    function event.keyboard(e)
        world:pub {"keyboard", keymap[e.key], e.press, e.state}
    end
    function event.dropfiles(...)
        world:pub {"dropfiles", ...}
    end
    local size
    local viewport
    local sizeChanged = false
    local viewportChanged = false
    function event.size(e)
        size = e
        sizeChanged = true
    end
    function event.set_viewport(e)
        viewport = e.viewport
        viewportChanged = true
    end
    function event.update()
        if sizeChanged then
            sizeChanged = false
            if not viewportChanged then
                rmlui_sendmsg("set_viewport", {
                    x = 0,
                    y = 0,
                    w = size.w,
                    h = size.h,
                })
            end
            world:pub {"resize", size.w, size.h}
        end
        if viewportChanged then
            viewportChanged = false
            rmlui_sendmsg("set_viewport", {
                x = viewport.x,
                y = viewport.y,
                w = viewport.w,
                h = viewport.h,
            })
            world:pub{"scene_viewrect_changed", viewport}
        end
    end
    if platform.os ~= "ios" and platform.os ~= "android" then
        local mg = require "mouse_gesture" (world)
        event.mousewheel = mg.mousewheel
        if world.args.ecs.enable_mouse then
            function event.mouseclick(e)
                world:set_mouse(e)
                mg.mouseclick(e)
                world:pub {"mouse", e.what, e.state, e.x, e.y}
            end
            function event.mousemove(e)
                world:set_mouse(e)
                mg.mousemove(e)
                if e.what.LEFT then
                    world:pub {"mouse", "LEFT", "MOVE", e.x, e.y}
                end
                if e.what.MIDDLE then
                    world:pub {"mouse", "MIDDLE", "MOVE", e.x, e.y}
                end
                if e.what.RIGHT then
                    world:pub {"mouse", "RIGHT", "MOVE", e.x, e.y}
                end
            end
        else
            event.mouseclick = mg.mouseclick
            event.mousemove = mg.mousemove
        end
    end
    return event
end

local world = {}

function world:dispatch_message(e)
    local func = self._inputmgr[e.type]
    if func then
        func(e)
    end
end

local m = {}

function m:init()
    self._inputmgr = create(self)
    self.dispatch_message = world.dispatch_message
end

function m:enable_imgui()
    self._enable_imgui = true
    ImGui = import_package "ant.imgui"
end

function m:filter_imgui(from, to)
    if not self._enable_imgui then
        for i = 1, #from do
            local e = from[i]
            to[#to+1] = e
            from[i] = nil
        end
        return
    end
    for i = 1, #from do
        local e = from[i]
        if not ImGui.DispatchEvent(e) then
            to[#to+1] = e
        end
        from[i] = nil
    end
end

return m

local platform = require "bee.platform"
local ltask = require "ltask"
local ImGui = require "imgui"
local ImGuiIO = ImGui.io

local keymap = {}

for name, index in pairs(ImGui.enum.Key) do
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
    function event.size(e)
        if not __ANT_EDITOR__ then
            rmlui_sendmsg("set_viewport", {
                x = 0,
                y = 0,
                w = e.w,
                h = e.h,
                ratio = world.args.framebuffer.ratio,
            })
        end
        local fb = world.args.framebuffer
        fb.width, fb.height = e.w, e.h
        world:pub {"resize", e.w, e.h}
    end
    function event.set_viewport(e)
        local vp = e.viewport
        rmlui_sendmsg("set_viewport", {
            x = vp.x,
            y = vp.y,
            w = vp.w,
            h = vp.h,
            ratio = world.args.framebuffer.ratio,
        })
        world:pub{"world_viewport_changed", vp}
    end
    if platform.os ~= "ios" and platform.os ~= "android" then
        local mg = require "mouse_gesture" (world)
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
    return event
end

local ImGuiEvent = {}

function ImGuiEvent.touch(e)
    if e.state == "began" then
        ImGuiIO.AddMouseButtonEvent(0, true)
    elseif e.state == "ended" then
        ImGuiIO.AddMouseButtonEvent(0, false)
    end
    return ImGuiIO.WantCaptureMouse
end

function ImGuiEvent.gesture(e)
    if e.what == "pinch" then
        ImGuiIO.AddMouseWheelEvent(e.velocity, e.velocity)
    end
    return ImGuiIO.WantCaptureMouse
end

function ImGuiEvent.keyboard(e)
    if e.press == 1 then
        ImGuiIO.AddKeyEvent(e.key, true);
    elseif e.press == 0 then
        ImGuiIO.AddKeyEvent(e.key, false);
    end
    return ImGuiIO.WantCaptureKeyboard
end

function ImGuiEvent.inputchar(e)
    if e.what == "native" then
        ImGuiIO.AddInputCharacter(e.code)
    elseif e.what == "utf16" then
        ImGuiIO.AddInputCharacterUTF16(e.code)
    end
end

function ImGuiEvent.focus(e)
    ImGuiIO.AddFocusEvent(e.focused)
end

local world = {}

function world:dispatch_message(e)
    if self._enable_imgui then
        local func = ImGuiEvent[e.type]
        if func then
            if func(e) then
                return
            end
        end
    end
    local func = self._inputmgr[e.type]
    if func then
        func(e)
    end
end

function world:enable_imgui()
    self._enable_imgui = true
end

local m = {}

function m:init()
    self._inputmgr = create(self)
    self.dispatch_message = world.dispatch_message
    self.enable_imgui = world.enable_imgui
end

return m

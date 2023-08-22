local ecs = ...
local world = ecs.world
local w = world.w

local ltask = require "ltask"
local ServiceRmlUi = ltask.queryservice "ant.rmlui|rmlui"
local irq = ecs.require "ant.render|render_system.renderqueue"
local hwi = import_package "ant.hwi"

local rmlui_sys = ecs.system "rmlui_system"

function rmlui_sys:init()
    local vp = world.args.viewport
    ecs.create_entity{
        policy = {
            "ant.general|name",
            "ant.render|render_target",
            "ant.render|watch_screen_buffer",
        },
        data = {
            rmlui_obj = true,
            render_target = {
                view_rect = {x=vp.x, y=vp.y, w=vp.w, h=vp.h},
                viewid = hwi.viewid_get "uiruntime",
                clear_state = {
                    clear = "",
                },
            },
            watch_screen_buffer = true,
            name = "rmlui_obj",
        }
    }
end

local vp_changed_mb = world:sub{"world_viewport_changed"}

function rmlui_sys:entity_init()
    for q in w:select "INIT rmlui_obj render_target:in" do
        local rt = q.render_target
        local vr = rt.view_rect
        irq.set_view_rect("rmlui_obj", vr)
        ltask.send(ServiceRmlUi, "update_context_size", vr.w, vr.h, world.args.framebuffer.ratio)
    end

    for _, vr in vp_changed_mb:unpack() do
        local rml = w:first("rmlui_obj render_target:in")
        if rml then
            irq.set_view_rect("rmlui_obj", vr)
            ltask.send(ServiceRmlUi, "update_context_size", vr.w, vr.h, world.args.framebuffer.ratio)
        end
    end
end


local S = ltask.dispatch()

local msgqueue = {}

function S.rmlui_message(...)
	msgqueue[#msgqueue+1] = {...}
end

local windows = {}
local events = {}

function rmlui_sys:ui_update()
    if #msgqueue == 0 then
        return
    end
    local mq = msgqueue
    msgqueue = {}
    for i = 1, #mq do
        local msg = mq[i]
        local name, data = msg[1], msg[2]
        local window = windows[name]
        local event = events[name]
        if window and event and event.message then
            event.message {
                source = window,
                data = data,
            }
        end
    end
end

function rmlui_sys:exit()
    for _, window in pairs(windows) do
        window.close()
    end
end

local iRmlUi = {}

function iRmlUi.open(name, url)
    url = url or name
    ltask.send(ServiceRmlUi, "open", name, url)
    local window = {}
    local event = {}
    windows[name] = window
    events[name] = event
    function window.close()
        ltask.send(ServiceRmlUi, "close", name)
        windows[name] = nil
        events[name] = nil
    end
    function window.postMessage(data)
        ltask.send(ServiceRmlUi, "postMessage", name, data)
    end
    function window.addEventListener(type, listener)
        event[type] = listener
    end
    return window
end

return iRmlUi

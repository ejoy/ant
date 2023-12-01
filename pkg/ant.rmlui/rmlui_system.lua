local ecs = ...
local world = ecs.world
local w = world.w

local ltask = require "ltask"
local ServiceRmlUi = ltask.queryservice "ant.rmlui|rmlui"

local rmlui_sys = ecs.system "rmlui_system"

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

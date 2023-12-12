local ecs = ...
local world = ecs.world
local w = world.w

local ltask = require "ltask"
local message = require "core.message"
local ServiceRmlUi = ltask.queryservice "ant.rmlui|rmlui"

local rmlui_sys = ecs.system "rmlui_system"

local windows = {}

function rmlui_sys:ui_update()
    message.dispatch()
end

function rmlui_sys:exit()
    for window in pairs(windows) do
        window.close()
    end
end

local iRmlUi = {}

function iRmlUi.open(name, url, ...)
    url = url or name
    ltask.send(ServiceRmlUi, "open", name, url, ...)
    local window = {}
    windows[window] = true
    function window.close()
        ltask.send(ServiceRmlUi, "close", name)
        windows[window] = nil
    end
    return window
end

iRmlUi.onMessage = message.on

function iRmlUi.callMessage(...)
    return message.call(ServiceRmlUi, ...)
end

function iRmlUi.sendMessage(...)
    message.send(ServiceRmlUi, ...)
end

return iRmlUi

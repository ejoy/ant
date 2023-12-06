local ecs = ...
local world = ecs.world
local w = world.w

local ltask = require "ltask"
local message = require "core.message"
local ServiceRmlUi = ltask.queryservice "ant.rmlui|rmlui"

local rmlui_sys = ecs.system "rmlui_system"

local S = ltask.dispatch()
S.sendMessage = message.send
S.callMessage = message.call

local windows = {}


function rmlui_sys:ui_update()
    message.dispatch()
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
    windows[name] = window
    function window.close()
        ltask.send(ServiceRmlUi, "close", name)
        windows[name] = nil
    end
    return window
end

iRmlUi.onMessage = message.set

function iRmlUi.callMessage(...)
    return ltask.call(ServiceRmlUi, "callMessage", ...)
end

function iRmlUi.sendMessage(...)
    ltask.send(ServiceRmlUi, "sendMessage", ...)
end

return iRmlUi

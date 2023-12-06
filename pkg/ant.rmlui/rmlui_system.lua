local ecs = ...
local world = ecs.world
local w = world.w

local ltask = require "ltask"
local ServiceRmlUi = ltask.queryservice "ant.rmlui|rmlui"

local rmlui_sys = ecs.system "rmlui_system"

local S = ltask.dispatch()

local msgqueue = {}
local msghandler = {}
local windows = {}

local MESSAGE_SEND <const> = 0
local MESSAGE_CALL <const> = 1

function S.rmlui_send(...)
    msgqueue[#msgqueue+1] = {MESSAGE_SEND, ...}
end

function S.rmlui_call(...)
    local msg = {MESSAGE_CALL, ...}
    msgqueue[#msgqueue+1] = msg
    return ltask.wait(msg)
end

function rmlui_sys:ui_update()
    if #msgqueue == 0 then
        return
    end
    local mq = msgqueue
    msgqueue = {}
    for i = 1, #mq do
        local msg = mq[i]
        local type = msg[1]
        if type == MESSAGE_SEND then
            local what = msg[2]
            local func = msghandler[what]
            if func then
                func(table.unpack(msg, 3))
            end
        elseif type == MESSAGE_CALL then
            local what = msg[2]
            local func = msghandler[what]
            if func then
                func(table.unpack(msg, 3))
            end
            ltask.wakeup(msg)
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
    windows[name] = window
    function window.close()
        ltask.send(ServiceRmlUi, "close", name)
        windows[name] = nil
    end
    function window.postMessage(...)
        ltask.send(ServiceRmlUi, "postMessage", name, ...)
    end
    return window
end

function iRmlUi.onMessage(what, func)
    msghandler[what] = func
end

function iRmlUi.callMessage(...)
    return ltask.call(ServiceRmlUi, "callMessage", ...)
end

function iRmlUi.sendMessage(...)
    ltask.send(ServiceRmlUi, "sendMessage", ...)
end

return iRmlUi

local ltask = require "ltask"

local m = {}

local msgqueue = {}
local msghandler = {}

local MESSAGE_SEND <const> = 0
local MESSAGE_CALL <const> = 1

function m.on(what, func)
    msghandler[what] = func
end

function m.send(id, ...)
    ltask.send(id, "sendMessage", ...)
end

function m.call(id, ...)
    return ltask.call(id, "callMessage", ...)
end

function m.dispatch()
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

local S = ltask.dispatch {}

function S.sendMessage(...)
    msgqueue[#msgqueue+1] = {MESSAGE_SEND, ...}
end

function S.callMessage(...)
    local msg = {MESSAGE_CALL, ...}
    msgqueue[#msgqueue+1] = msg
    return ltask.wait(msg)
end

return m

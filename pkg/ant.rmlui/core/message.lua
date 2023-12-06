local ltask = require "ltask"

local m = {}

local msgqueue = {}
local msghandler = {}

local MESSAGE_SEND <const> = 0
local MESSAGE_CALL <const> = 1

function m.set(what, func)
    msghandler[what] = func
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

function m.send(...)
    msgqueue[#msgqueue+1] = {MESSAGE_SEND, ...}
end

function m.call(...)
    local msg = {MESSAGE_CALL, ...}
    msgqueue[#msgqueue+1] = msg
    return ltask.wait(msg)
end

return m

local lsocket = require 'lsocket'
local proto = require 'new-debugger.protocol'

local listen
local channel
local stat = {}

local m = {}
function m.start(ip, port)
    channel = assert(lsocket.connect(ip, port))
end

function m.update(timeout)
    return true
end

function m.recv()
    assert(channel)
    local data = proto.recv(channel:recv(), stat)
    return data
end

local function sendstring(s)
    local from = 1
    local len = #s
    while from <= len do
        lsocket.select(nil, {channel})
        from = from + assert(channel:send(s:sub(from)))
    end
end

function m.send(data)
    assert(channel)
    sendstring(proto.send(data))
end

function m.close()
    assert(channel)
    channel:close()
    channel = nil
    stat = {}
end

return m

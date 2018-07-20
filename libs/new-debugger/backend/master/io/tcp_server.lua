local lsocket = require 'lsocket'
local proto = require 'new-debugger.protocol'

local listen
local channel
local stat = {}

local m = {}
function m.start(ip, port)
    listen = assert(lsocket.bind(ip, port))
end

function m.update()
    if channel then
        return true
    end
    assert(listen)
    if not lsocket.select ({listen}, 0) then
        return false
    end
    channel = assert(listen:accept())
    return true
end

function m.recv()
    assert(channel)
    if not lsocket.select({channel}, 0) then
        return proto.recv('', stat)
    end
    return proto.recv(channel:recv(), stat)
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

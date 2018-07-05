local lsocket = require 'lsocket'
local proto = require 'new-debugger.protocol'

local listen
local channel

local m = {}
function m.start(port)
    listen = assert(lsocket.bind("127.0.0.1", port))
end

function m.select(timeout)
    assert(listen)
    if not lsocket.select ({listen}, timeout) then
        return false
    end
    channel = assert(listen:accept())
    listen:close()
    listen = nil
    return true
end

function m.recv()
    assert(channel)
    return proto.recv(channel:recv())
end

function m.send(data)
    assert(channel)
    channel:send(proto.send(data))
end

return m

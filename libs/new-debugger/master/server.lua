local lsocket = require 'lsocket'
local proto = require 'new-debugger.master.protocol'

local listen
local channel

local m = {}
function m.start(port)
    listen = assert(lsocket.bind("127.0.0.1", port))
end

function m.update(timeout)
    if channel then
        return true
    end
    assert(listen)
    if not lsocket.select ({listen}, timeout) then
        return false
    end
    channel = assert(listen:accept())
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

function m.close()
    assert(channel)
    channel:close()
    channel = nil
end

return m

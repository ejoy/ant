local lsocket = require 'lsocket'
local socket = require 'debugger.socket'

local listen
local fd
local frecv

local m = {}
function m.start(ip, port)
    listen = assert(lsocket.bind(ip, port))
end

function m.event_in(f)
    frecv = f
end

function m.update()
    socket.update()
    if fd then
        return true
    end
    assert(listen)
    if not lsocket.select ({listen}, 0) then
        return false
    end
    fd = assert(listen:accept())
    socket.init(fd, function()
        frecv(fd:recv())
    end)
    return true
end

function m.send(data)
    socket.send(fd, data)
end

function m.close()
    fd:close()
    fd = nil
end

return m

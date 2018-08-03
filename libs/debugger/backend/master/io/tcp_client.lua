local lsocket = require 'lsocket'
local socket = require 'debugger.socket'

local listen
local fd

local m = {}
function m.start(ip, port)
    fd = assert(lsocket.connect(ip, port))
end

function m.event_in(frecv)
    socket.init(fd, function()
        frecv(fd:recv())
    end)
end

function m.update()
    socket.update()
    return not not fd
end

function m.send(data)
    socket.send(fd, data)
end

function m.close()
    fd:close()
    fd = nil
    os.exit(true, true)
end

return m

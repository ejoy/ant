local lsocket = require 'lsocket'
local socket = require 'debugger.socket'

local mt = {}
mt.__index = mt

function mt:event_in(frecv)
    socket.init(self.fd, function()
        frecv(self.fd:recv())
    end)
end

function mt:update()
    socket.update()
    return not not self.fd
end

function mt:send(data)
    socket.send(self.fd, data)
end

function mt:close()
    self.fd:close()
    self.fd = nil
end

return function(ip, port)
    return setmetatable({
        fd = assert(lsocket.connect(ip, port))
    }, mt)
end

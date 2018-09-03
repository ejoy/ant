local lsocket = require 'lsocket'
local socket = require 'debugger.socket'

local mt = {}
mt.__index = mt

function mt:event_in(f)
    self.frecv = f
end

function mt:event_close(f)
    self.fclose = f
end

function mt:update()
    socket.update()
    if self.fd then
        return true
    end
    assert(self.listen)
    if not lsocket.select ({self.listen}, 0) then
        return false
    end
    self.fd = assert(self.listen:accept())
    socket.init(self.fd, function()
        local data = self.fd:recv()
        if data == nil then
            self:close()
        elseif data ~= false then
            self.frecv(data)
        end
    end)
    return true
end

function mt:send(data)
    socket.send(self.fd, data)
end

function mt:close()
    if self.fclose then
        self.fclose()
    end
    socket.close(self.fd)
    self.fd:close()
    self.fd = nil
end

return function(ip, port)
    return setmetatable({
        listen = assert(lsocket.bind(ip, port))
    }, mt)
end

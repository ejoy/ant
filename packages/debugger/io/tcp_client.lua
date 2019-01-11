local lsocket = require 'lsocket'
local socket = require 'debugger.socket'

local mt = {}
mt.__index = mt

function mt:event_in(frecv)
    socket.init(self.fd, function()
        local data = self.fd:recv()
        if data == nil then
            self:close()
        elseif data ~= false then
            frecv(data)
        end
    end)
end

function mt:event_close(f)
    self.fclose = f
end

function mt:update()
    socket.update()
    return not not self.fd
end

function mt:send(data)
    socket.send(self.fd, data)
end

function mt:close()
    if not self.fd then
        return
    end
    local fd = self.fd
    self.fd = nil
    if self.fclose then
        self.fclose()
    end
    socket.close(fd)
    fd:close()
end

return function(ip, port)
    return setmetatable({
        fd = assert(lsocket.connect(ip, port))
    }, mt)
end

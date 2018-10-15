local cdebug = require 'debugger.frontend'
local stdin = require 'debugger.frontend.stdin'
local socket = require 'debugger.socket'

local mt = {}
mt.__index = mt

io.stdin:setvbuf 'no'
io.stdout:setvbuf 'no'
if cdebug.os() == 'windows' then
    cdebug.filemode(io.stdin, 'b')
    cdebug.filemode(io.stdout, 'b')
end

function mt:event_in(f)
    local fd = stdin.fd
    socket.init(fd, function()
        f(fd:recv() or '')
    end)
end

function mt:event_close()
end

function mt:update()
    stdin.update()
    socket.update()
    return true
end

function mt:send(data)
    io.stdout:write(data)
end

function mt:close()
end

return function()
    return setmetatable({}, mt)
end

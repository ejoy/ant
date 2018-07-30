local cdebug = require 'debugger.frontend'
local proto = require 'debugger.protocol'
local stdin = require 'debugger.frontend.stdin'
local select = require 'debugger.frontend.select'
local proxy = nil
local stat = {}
local m = {}

io.stdin:setvbuf 'no'
io.stdout:setvbuf 'no'
if cdebug.os() == 'windows' then
    cdebug.filemode(io.stdin, 'b')
    cdebug.filemode(io.stdout, 'b')
end

local fd = stdin.fd
select.read(fd, function()
    while true do
        local pkg = proto.recv(fd:recv() or '', stat)
        if pkg then
            proxy.send(pkg)
        else
            break
        end
    end
end)

function m.initialize()
    proxy = require 'debugger.frontend.proxy'
end

function m.send(pkg)
    io.stdout:write(proto.send(pkg))
end

function m.update()
    stdin.update()
end

return m

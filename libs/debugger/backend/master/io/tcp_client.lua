local lsocket = require 'lsocket'
local proto = require 'debugger.protocol'
local socket = require 'debugger.socket'

local listen
local fd
local stat = {}
local queue = {}

local m = {}
function m.start(ip, port)
    fd = assert(lsocket.connect(ip, port))
    socket.init(fd, function()
        while true do
            local msg = proto.recv(fd:recv(), stat)
            if msg then
                queue[#queue + 1] = msg
            else
                break
            end
        end
    end)
end

function m.update()
    socket.update()
    return not not fd
end

function m.recv()
    if #queue == 0 then
        return
    end
    return table.remove(queue, 1)
end

function m.send(data)
    socket.send(fd, proto.send(data))
end

function m.close()
    fd:close()
    fd = nil
    stat = {}
    queue = {}
    os.exit(true, true)
end

return m

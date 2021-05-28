local manager = require "ltask.manager"
local socket = require "socket"

manager.register "debug.listen"

local fd = socket.bind("tcp", "127.0.0.1", 4378)

local S = {}

function S.LISTEN()
    return socket.listen(fd)
end

return S

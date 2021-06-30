local socket = require "socket"

local fd = socket.bind("tcp", "127.0.0.1", 4378)

local S = {}

function S.LISTEN()
    return socket.listen(fd)
end

return S

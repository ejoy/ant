local ltask = require "ltask"
local socket = require "socket"
local protocol = require "protocol"
local LISTEN
local FD

ltask.fork(function ()
    LISTEN = socket.bind("tcp", "127.0.0.1", 2019)
    while true do
        local newfd = socket.listen(LISTEN)
        if newfd then
            if FD then
                socket.close(newfd)
            else
                FD = newfd
                print("Editor connected")
            end
        end
    end
end)

local S = {}

function S.MESSAGE(...)
    if not FD then return end
    if socket.send(FD, protocol.packmessage{...}) == nil then
        socket.close(FD)
        FD = nil
    end
end

function S.QUIT()
    if FD then
        socket.close(FD)
        FD = nil
    end
    if LISTEN then
        socket.close(LISTEN)
        LISTEN = nil
    end
    ltask.quit()
end

return S

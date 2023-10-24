local DeviceID = ...
local ltask = require "ltask"
local socket = require "socket"
local usbmuxd = require "usbmuxd"

local STATUS
local CLIENT_FD
local SERVER_FD

local function closeProxy()
    local sfd, cfd = SERVER_FD, CLIENT_FD
    if sfd then
        socket.close(sfd)
    end
    if cfd then
        socket.close(cfd)
    end
end

local function connectIOS()
    while true do
        local fd = assert(socket.connect(usbmuxd.get_address()))
        local a, b = usbmuxd.create_connect_package(DeviceID, 2018)
        if socket.send(fd, a) ~= nil and socket.send(fd, b) ~= nil then
            local function recvf(n)
                return socket.recv(fd, n)
            end
            local msg = usbmuxd.recv(recvf)
            if msg then
                assert(msg.MessageType == 'Result')
                if msg.Number == 0 then
                    return fd
                end
            end
        end
        ::continue::
        socket.close(fd)
        ltask.sleep(20)
    end
end

local function updateProxy()
    while STATUS == "Attached" do
        local cfd = connectIOS()
        local sfd = socket.connect('tcp', '127.0.0.1', 2018)
        SERVER_FD, CLIENT_FD = sfd, cfd
        for _ in ltask.request
            { ltask.self(), "__Proxy", sfd, cfd }
            { ltask.self(), "__Proxy", cfd, sfd }
        :select() do
            SERVER_FD, CLIENT_FD = nil, nil
            socket.close(sfd)
            socket.close(cfd)
            break
        end
    end
end

local S = {}

function S.Attached()
    STATUS = "Attached"
    closeProxy()
    updateProxy()
end

function S.Detached()
    STATUS = "Detached"
    closeProxy()
end

function S.Paired()
end

function S.__Proxy(from, to)
    while true do
        local data = socket.recv(from)
        if data == nil then
            return
        end
        if socket.send(to, data) == nil then
            return
        end
    end
end

return S

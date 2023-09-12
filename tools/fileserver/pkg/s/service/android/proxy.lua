local adb, deviceid, port = ...
local ltask = require "ltask"
local socket = require "socket"
local ServiceSubprocess = ltask.queryservice "subprocess"

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

local function connectAndroid()
    while true do
        local exitcode, msg = ltask.call(ServiceSubprocess, "run", {
            adb, "forward",  "tcp:"..port, "tcp:2018",
            stdout     = true,
            stderr     = "stdout",
            hideWindow = true,
        })
        if exitcode ~= 0 then
            --print(('Adb failed: [%d]%s'):format(exitcode, msg))
            return
        end
        local fd = assert(socket.connect('tcp', '127.0.0.1', port))
        local hand = socket.recv(fd, 14)
        if hand == "\12\00\10\00SHAKEHANDS" then
            return fd
        end
        socket.close(fd)
        ltask.sleep(20)
    end
end

local function updateProxy()
    while STATUS == "Attached" do
        local cfd = connectAndroid()
        if not cfd then
            STATUS = "Error"
            break
        end
        local sfd = socket.connect('tcp', '127.0.0.1', 2018)
        SERVER_FD, CLIENT_FD = sfd, cfd
        for _ in ltask.request
            { ltask.self(), "__Proxy", sfd, cfd }
            { ltask.self(), "__Proxy", cfd, sfd }
        :select() do
            SERVER_FD, CLIENT_FD = nil, nil
            socket.close(sfd)
            socket.close(cfd)
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

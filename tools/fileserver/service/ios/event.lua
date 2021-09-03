local ltask = require "ltask"
local socket = require "socket"
local usbmuxd = require "usbmuxd"

local devices = {}

local function notify(MessageType, info)
    print('IOS Device '..MessageType, info.sn)
    ltask.send(info.sid, MessageType)
end

local eventfd, err = socket.connect(usbmuxd.get_address())
if not eventfd then
    --print("Error:", err)
    return
end
local a, b = usbmuxd.create_listen_package()
socket.send(eventfd, a)
socket.send(eventfd, b)
local function recvf(n)
    return socket.recv(eventfd, n)
end
while true do
    local event = usbmuxd.recv(recvf)
    if not event then
        return
    end
    if event.MessageType == 'Result' then
        assert(event.Number == 0, event.Number)
    elseif event.MessageType == 'Attached' then
        local info = devices[event.DeviceID]
        if not info then
            info = {}
            info.sid = ltask.spawn("ios.proxy", event.DeviceID)
            devices[event.DeviceID] = info
        end
        info.sn = event.Properties.SerialNumber
        notify(event.MessageType, info)
    elseif event.MessageType == 'Detached' then
        notify(event.MessageType, devices[event.DeviceID])
    elseif event.MessageType == 'Paired' then
        notify(event.MessageType, devices[event.DeviceID])
    else
        error('Unknown message: ' .. event.MessageType)
    end
end

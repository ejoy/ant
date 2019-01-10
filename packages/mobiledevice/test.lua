dofile "libs/editor.lua"

local usbmuxd = require "mobiledevice.usbmuxd"
local network = require "network"
local print_r = require "common/print_r"

local function connect_usbmuxd_socket()
	return assert(network.connect(usbmuxd.get_address()))
end

local function listen()
	local fd = connect_usbmuxd_socket()
	local header, payload = usbmuxd.create_listen_package()
	network.send(fd, header)
	network.send(fd, payload)
	return fd
end

local function update(fd)
    while true do
        local payload = usbmuxd.recv(fd)
        if payload then
            print('=====================')
            print_r(payload)
        else
            break
        end
    end
end

local monitor = listen()
local objs = {}
while true do
    if network.dispatch(objs) then
        for k,obj in ipairs(objs) do
            objs[k] = nil
            if obj == monitor then
                update(monitor)
            end
        end
    end
end

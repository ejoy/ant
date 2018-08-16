package.cpath = "../../../clibs/?.dll;../../../clibs/lib?.so;../../../clibs/?.so;" .. package.cpath
package.path = "../Common/?.lua;" .. "../../?/?.lua;".. package.path

local lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
local linda = lanes.linda()

function log(name)
	local tag = "[" .. name .. "] "
	local write = io.write
	return function(fmt, ...)
		write(tag)
		write(string.format(fmt, ...))
		write("\n")
	end
end



local resp_table = {}
local function HandleMessage()
    while true do
        local key, value = linda:receive(0.001, "log", "response")
        if key == "log" then
            table.insert(resp_table, {"log", value})
        elseif key == "response" then
            if value[1] == "CONNECT" then
                print("~~CONNECT", value[1], value[2])
                table.insert(resp_table, {"connect", 1, value[2]})
            elseif value[1] == "DISCONNECT" then
                print("~~DISCONNECT", value[1], value[2])
                table.insert(resp_table, {"connect", 0, value[2]})
            elseif value[1] == "SCREENSHOT" then
                table.insert(resp_table, {"screenshot", value[2]})
            end
        else
            break
        end
    end
end

local function CreateServerThread(address, port, linda)
    local server_io = require "server_new_io"
    local s = server_io.new(address, port, linda)
    while true do
        s:mainloop(0.05)
    end
end

--handle devices names, send connect, disconnect command to IO
local current_devices = {}
--local connected_devices = {}
local libimobiledevicelua = require "libimobiledevicelua"

local server_ins = {s = nil}

function server_ins.GetNewDeviceInfo()
    local devices = libimobiledevicelua.GetDevices()
    local new_devices = {}
    for k, v in ipairs(devices) do
        if current_devices[v] == nil then
            current_devices[v] = true
            table.insert(new_devices, v);
        end
    end

    return new_devices
end

--server_repo = nil

function server_ins:init(address, port)
    --self.s = server.new{address = address, port = port}

    local server_io, err = lanes.gen("*", {globals = {PLATFORM = PLATFORM}}, CreateServerThread)(address, port, linda)
    if not server_io then
        print("server_io error: "..tostring(err))
    end
end

function server_ins:update()
    print("server framework update")

    HandleMessage()
end

function server_ins:RecvResponse()
    local return_resp = {}

    for _, v in ipairs(resp_table) do
        table.insert(return_resp, v)
    end

    resp_table = {}
    return return_resp
end

function server_ins:HandleCommand(udid, cmd, ...)
    print("udid", udid, cmd)
    if udid ~= nil and cmd ~= nil then
        linda:send("command", {udid = udid, cmd = cmd, cmd_data = {...}})
    end
end

function server_ins:SetProjectDirectoryPath(path)
    print("project directory set to", path)
    linda:send("proj dir", path)
end

return server_ins

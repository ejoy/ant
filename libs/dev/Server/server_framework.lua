package.cpath = "../../../clibs/?.dll;../../../clibs/lib?.so;../../../clibs/?.so;" .. package.cpath
package.path = "../Common/?.lua;" .. "../../?/?.lua;".. package.path

local lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
local linda = lanes.linda()

local resp_table = {}

local IOCommand_name = {"log", "response"}
local IOCommand_func = {}
IOCommand_func["log"] = function(value)
    table.insert(resp_table, {"log", value})
end

IOCommand_func["response"] = function(value)
    if value[1] == "CONNECT" then
        print("~~CONNECT", value[1], value[2])
        table.insert(resp_table, {"connect", 1, value[2]})
    elseif value[1] == "DISCONNECT" then
        print("~~DISCONNECT", value[1], value[2])
        table.insert(resp_table, {"connect", 0, value[2]})
    elseif value[1] == "SCREENSHOT" then
        table.insert(resp_table, {"screenshot", value[2]})
    end
end


local function HandleMessage()
    while true do
        local key, value = linda:receive(0.001, table.unpack(IOCommand_name))
        if key then
            IOCommand_func[key](value)
        else
            break
        end
    end
end

local function CreateServerThread(address, port, linda)
    local server_io = require "server_io"
    local s = server_io.new(address, port, linda)
    print("create server io")
    while true do
        s:mainloop(0.05)
    end
end

local function CreateFileWatchThread(path, linda)
    local server_filesys = require "server_filesys"
    local fs = server_filesys.new(linda, path)    
    
    while true do
        fs:mainloop()
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

function server_ins:init(address, port, fw_path)
    --self.s = server.new{address = address, port = port}
    local file_watch, err = lanes.gen("*", CreateFileWatchThread)(fw_path, linda)
    if not file_watch then
        print("unable to create file watch thread: " .. tostring(err))
    end
    
    local server_io, err = lanes.gen("*",  CreateServerThread)(address, port, linda)
    if not server_io then
        print("server_io error: "..tostring(err))
    end
end

function server_ins:update()
    --print("server framework update")
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

function server_ins:SendPackage(pkg)
    print("send package server framework", pkg[1])
    linda:send("package", pkg)
end

function server_ins:RegisterIOCommand(cmd, func)
    table.insert(IOCommand_name, cmd)
    IOCommand_func[cmd] = func

    linda:send("RegisterTransmit", cmd)
end



return server_ins

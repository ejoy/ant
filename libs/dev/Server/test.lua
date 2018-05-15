package.cpath = "../../../clibs/?.dll;../../../clibs/lib?.so;../../../clibs/?.so;" .. package.cpath
package.path = "../Common/?.lua;" .. "../../?/?.lua;".. package.path

local lanes = require "lanes"
if lanes.configure then lanes.configure() end
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

local log_table = {}
local function HandleMessage()
    while true do
        local key, value = linda:receive(0.05, "log")
        if value then
            --do something here
            table.insert(log_table, value)
        else
            break
        end
    end
end

local function CreateServerThread(config, linda)

    local server = require "server"
    local s = server.new(config, linda)
    while true do
        s:mainloop(0.05)
    end
end

local server_ins = {s = nil}

function server_ins:init(address, port)
    --self.s = server.new{address = address, port = port}

    local server_io = lanes.gen("*", CreateServerThread)({address = address, port = port}, linda)
end

function server_ins:update()
    HandleMessage()
end

function server_ins:recvlog()
    local return_log = {}

    for _, v in ipairs(log_table) do
        table.insert(return_log, v)
    end

    log_table = {}
    return return_log
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

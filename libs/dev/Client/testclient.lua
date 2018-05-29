package.cpath = "../../../clibs/?.dll;" .. package.cpath
package.path = "../Common/?.lua;../../?/?.lua;".. package.path
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

local filemanager = require "filemanager"
local file_mgr = filemanager.new()

local lsocket = require "lsocket"
lanes.register("lsocket", lsocket)

--c:send("PING")
--c:send("GET", "ServerFiles/test(2).txt")
--c:send("GET", "ServerFiles/ow_gdc.mp4")
--c:send("GET", "ServerFiles/building.mp4")
--c:send("GET", "ServerFiles/test.txt")
--c:send("GET", "ServerFiles/hugetext.txt")
--c:send("LIST","ClientFiles")

local function CreateIOThread(linda)
    local client = require "client"

    local c = client.new("127.0.0.1", 8888, linda)

    while true do
        c:mainloop(1)
        --print("io mainloop updating")
        local resp = c:pop()
        if resp then
            c:process_response(resp)
        end
    end
end

local client_io = lanes.gen("*",{package = {path = package.path, cpath = package.cpath, preload = package.preload}}, CreateIOThread)(linda)

--local temp = client_io[1]

--[[
local function remote_searcher (name)
    local full_path = name..".lua"
    local request = {"OPEN", full_path}
    linda:send("request", request)

    while true do
        local key, value = linda:receive(0.05, "mem_data")
        if value~=nil then
            print("receive data", type(value))
            return load(value)
        end
    end
end
table.insert(package.searchers, remote_searcher)

local count = 1
local command_c = 0
while true do
    if count == 0 and command_c < 1 then
        --local request = {"GET", "ServerFiles/hugetext.txt"}
        local request = {"LIST","Files"}

        --local request = {"GET", "ServerFiles/hugetext.txt"}
        linda:send("request", request)
        command_c = command_c + 1
        print("command sent")
    end

    count = (count + 1) % 5000000
end
--]]
package.remote_searchpath = "ServerFiles"
package.cpath = "../../../clibs/?.dll"
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
    --c:send("GET", "ServerFiles/building.mp4")
    while true do
        c:mainloop(1)
        local resp = c:pop()
        if resp then
            c:process_response(resp)
        end
    end
end

local io = lanes.gen("*", CreateIOThread)(linda)

local function remote_searcher (name)
    local full_path = package.remote_searchpath .. "/" ..name..".lua"
    local request = {"OPEN", full_path}
    linda:send("request", request)

    while true do
        local key, value = linda:receive(0.05, "mem_data")
        if value~=nil then
            print(type(value))
            return load(value)
        end
    end
end
table.insert(package.searchers, remote_searcher)


local clientlogic = require "clientlogic"
local cl = clientlogic.Init(linda)

local count = 1
local command_c = 0
while true do
    cl:MainLoop()
    if count == 0 and command_c < 1 then
        --local request = {"GET", "ServerFiles/hugetext.txt"}
        local request = {"LIST","ClientFiles"}

        --local request = {"GET", "ServerFiles/hugetext.txt"}
        cl.SendRequest("request", request)
        command_c = command_c + 1
    end

    count = (count + 1) % 5000000
end
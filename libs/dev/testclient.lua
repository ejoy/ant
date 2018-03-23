package.cpath = "../../clibs/?.dll"

function log(name)
	local tag = "[" .. name .. "] "
	local write = io.write
	return function(fmt, ...)
		write(tag)
		write(string.format(fmt, ...))
		write("\n")
	end
end

local client = require "client"

local c = client.new("127.0.0.1", 8888)

--c:send("PING")
--c:send("GET", "ServerFiles/test(2).txt")
--c:send("GET", "ServerFiles/ow_gdc.mp4")
--c:send("GET", "ServerFiles/building.mp4")
--c:send("GET", "ServerFiles/test.txt")
--c:send("GET", "ServerFiles/hugetext.txt")
c:send("LIST","ClientFiles")
while true do
	c:mainloop(1)
	local resp = c:pop()
	if resp then
		c:process_response(resp)
	end
end

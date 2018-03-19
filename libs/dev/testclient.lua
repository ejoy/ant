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

c:send("PING")

while true do
	c:mainloop(1)
	local resp = c:pop()
	if resp then
		for k,s in ipairs(resp) do
			print(k,s)
		end
	end
end

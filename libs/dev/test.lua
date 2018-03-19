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

local server = require "server"

local s = server.new { address = "127.0.0.1", port = 8888 }

while true do
	s:mainloop(1)
end





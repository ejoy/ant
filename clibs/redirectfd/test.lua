package.cpath = "?.dll;../?.dll"

local lsocket = require "lsocket"
local redirectfd = require "redirectfd"

local function create_pipe()
	local port = 10000
	local socket

	repeat
		socket = assert(lsocket.bind( "127.0.0.1", port))
		if not socket then
			port = port + 1
		end
	until socket

	local ofd = assert(lsocket.connect("127.0.0.1", port))
	lsocket.select {socket}
	local ifd = socket:accept()
	socket:close()
	lsocket.select({}, {ofd})
	return ifd,ofd
end

local ifd,ofd = create_pipe()

redirectfd.init(ofd:info().fd)

print ("Hello World")

lsocket.select {ifd}

-- output to stderr
io.stderr:write("STDOUT:" .. ifd:recv())

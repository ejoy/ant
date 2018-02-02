local path,cpath,port = ...
package.path = path
package.cpath = cpath

local lsocket = require "lsocket"
local fd = assert(lsocket.connect("127.0.0.1", port))

lsocket.select({},{fd})

local pack = require "debugger.pack"
local channel = pack.new(fd)

function run(cmd)
	channel:send(cmd)
	return channel:recv()
end

function frames()
	return run "frames"
end

function frame(n)
	return run(string.format("frame %d", n))
end
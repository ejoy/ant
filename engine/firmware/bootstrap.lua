__ANT_RUNTIME__ = "0.0.1"

local os = (require "platform".OS):lower()
local config = {
	repopath = "./",
	vfspath = "vfs.lua",
	nettype = (os ~= "ios") and "connect" or "listen",
	address = "127.0.0.1",
	port = 2018,
	rootname = arg[1],
}

local thread = require "thread"

thread.newchannel "IOreq"

local errlog = thread.channel_produce "errlog"
local io_req = thread.channel_produce "IOreq"

local errthread = thread.thread([[
	-- Error Thread
	local thread = require "thread"
	local err = thread.channel_consume "errlog"
	while true do
		local msg = err()
		if msg == "EXIT" then
			break
		end
		print("ERROR:" .. msg)
	end
]])

local iothread = thread.thread([[
	-- IO Thread
	local fw = require "firmware"
	assert(fw.loadfile "io.lua")(fw.loadfile)
]])

io_req(false, config)
io_req:call("FETCH", 'engine/firmware')
local bootloader = io_req:call("GET", 'engine/firmware/bootloader.lua')
io_req:call("EXIT")

errlog:push("EXIT")
thread.wait(iothread)
thread.wait(errthread)
thread.reset()

local function loadfile(path, name)
	local f = io.open(path)
	if not f then
		return nil, ('%s:No such file or directory.'):format(name)
	end
	local str = f:read 'a'
	f:close()
	return load(str, "@/" .. name)
end
assert(loadfile(bootloader, 'engine/firmware/bootloader.lua'))(config)

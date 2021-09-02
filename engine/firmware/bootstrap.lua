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

local function vfs_init()
	io_req(false, config)
end

local function fetchfirmware()
	io_req(false, "FETCHALL", 'engine/firmware')

	-- wait finish
	local l = io_req:call("LIST", 'engine/firmware')
	local result
	for name, type in pairs(l) do
		assert(type == false)
		local r = io_req:call("GET", 'engine/firmware/' .. name)
		if name == 'bootloader.lua' then
			result = r
		end
	end
	assert(result ~= nil)
	return result
end

local function vfs_exit()
	return io_req:call("EXIT")
end

vfs_init()
local bootloader = fetchfirmware()
vfs_exit()
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

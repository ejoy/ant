__ANT_RUNTIME__ = "0.0.1"

local platform = require "platform"
local config = {
	repopath = "./",
	vfspath = "vfs.lua",
	nettype = (platform.OS ~= "iOS") and "connect" or "listen",
	address = "127.0.0.1",
	port = 2018,
}

local thread = require "thread"
local threadid = thread.id

thread.newchannel "IOreq"
thread.newchannel ("IOresp" .. threadid)

local errlog = thread.channel_produce "errlog"
local io_req = thread.channel_produce "IOreq"
local io_resp = thread.channel_consume ("IOresp" .. threadid)

local errthread = thread.thread([[
	-- Error Thread
	package.searchers[1] = ...
	package.searchers[2] = nil
	local thread = require "thread"
	local err = thread.channel_consume "errlog"
	while true do
		local msg = err()
		if msg == "EXIT" then
			break
		end
		print("ERROR:" .. msg)
	end
]], package.searchers[3])

local iothread = thread.thread(([[
	-- IO Thread
	package.searchers[1] = ...
	package.searchers[2] = nil
	local fw = require "firmware"
	assert(fw.loadfile "io.lua")(fw.loadfile, %q)
]]):format(arg[1]), package.searchers[3])

local function vfs_init()
	io_req:push(config)
end

local function fetchfirmware()
	io_req("FETCHALL", false, 'engine/firmware')

	-- wait finish
	io_req("LIST", threadid, 'engine/firmware')
	local l = io_resp()
	local result
	for name, type in pairs(l) do
		assert(type == false)
		io_req("GET", threadid, 'engine/firmware/' .. name)
		if name == 'bootloader.lua' then
			result = io_resp()
		else
			io_resp()
		end
	end
	assert(result ~= nil)
	return result
end

local function vfs_exit()
	io_req("EXIT", threadid)
	return io_resp()
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

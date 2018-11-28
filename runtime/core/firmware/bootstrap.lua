local repopath, address, port = "./", "127.0.0.1", 2018
for _, v in ipairs(arg) do
	if v:sub(1,4) == '-ip=' then
		address, port = v:sub(5):match "^(.*):(.*)$"
		port = tonumber(port)
		break
	end
end

local platform = require "platform"
local thread = require "thread"
local threadid = thread.id

thread.newchannel "IOreq"
thread.newchannel ("IOresp" .. threadid)

local io_req = thread.channel_produce "IOreq"
local io_resp = thread.channel_consume ("IOresp" .. threadid)

local iothread = thread.thread([[
	-- IO Thread
	package.searchers[1] = ...
	package.searchers[2] = nil
	local fw = require "firmware"
	assert(fw.loadfile "io.lua")(fw.loadfile)
]], package.searchers[3])

local function vfs_init()
	io_req:push {
		repopath = repopath,
		vfspath = "vfs.lua",
		address = address,
		port = port,
		platform = platform.os()
	}
end

local function fetchfirmware()
	io_req("FETCHALL", false, 'firmware')

	-- wait finish
	io_req("LIST", threadid, 'firmware')
	local l = io_resp()
	local result
	for name, type in pairs(l) do
		assert(type == false)
		io_req("GET", threadid, 'firmware/' .. name)
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
thread.wait(iothread)
thread.reset()

local function loadfile(path, name)
	local f, err = io.open(path)
	if not f then
		return nil, ('%s:No such file or directory.'):format(name)
	end
	local str = f:read 'a'
	f:close()
	return load(str, "@vfs://" .. name)
end
assert(loadfile(bootloader, 'firmware/bootloader.lua'))(repopath, address, port)

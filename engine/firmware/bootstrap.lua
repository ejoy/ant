__ANT_RUNTIME__ = "0.0.1"

local config = {
	rootname = arg[1],
	repopath = "./",
	vfspath = "vfs.lua",
	socket = nil,
	nettype = nil,
	address = nil,
	port = nil,
}

local address = ...

if address == nil then
	config.nettype = "connect"
	config.address = "127.0.0.1"
	config.port = 2018
elseif address == "USB" then
	config.nettype = "listen"
	config.address = "127.0.0.1"
	config.port = 2018
else
	config.nettype = "connect"
	local ip, port = address:match "^(%d+%.%d+%.%d+%.%d+):(%d+)"
	if ip and port then
		config.address = ip
		config.port = tonumber(port)
	else
		config.address = "127.0.0.1"
		config.port = 2018
	end
end


local thread = require "thread"
local fw = require "firmware"
local ls = require "lsocket"
local host = {}
local bootloader
local first = true
local quit
function host.init()
	return config
end
function host.update(apis, timeout)
	if first then
		first = false
		apis.request("FETCH", "/engine/firmware", {
			resolve = function ()
				quit = true
			end,
			reject = function (_, errmsg)
				error(errmsg)
			end,
		})
	end
	if quit then
		return true
	end
	thread.sleep(timeout)
end
function host.exit(apis)
	if apis.fd then
		if config.nettype == "listen" then
			config.socket = ls.tostring(apis.fd)
		else
			apis.fd:close()
		end
	end
	bootloader = assert(apis.repo:realpath '/engine/firmware/bootloader.lua')
end
assert(fw.loadfile "io.lua")(fw.loadfile, host)

local function loadfile(path, name)
	local f = io.open(path)
	if not f then
		return nil, ('%s:No such file or directory.'):format(name)
	end
	local str = f:read 'a'
	f:close()
	return load(str, "@/" .. name)
end
assert(loadfile(bootloader, '/engine/firmware/bootloader.lua'))(config)

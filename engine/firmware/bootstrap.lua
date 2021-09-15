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
local fw = require "firmware"
local host = {}
local bootloader
local first = true
local quit
function host.init()
	return config
end
function host.update(io, timeout)
	if first then
		first = false
		io.request("FETCH", "engine/firmware", {
			resolve = function ()
				bootloader = assert(io.repo:realpath 'engine/firmware/bootloader.lua')
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
function host.exit(io)
	if io.fd then
		io.fd:close()
	end
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
assert(loadfile(bootloader, 'engine/firmware/bootloader.lua'))(config)

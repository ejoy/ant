__ANT_RUNTIME__ = "0.0.1"

local platform = require "bee.platform"

local needcleanup, type, address

if platform.os == "ios" then
	local setting = require "platform".setting
	local clean_up_next_time = setting("clean_up_next_time")
	if clean_up_next_time == true then
		setting("clean_up_next_time", false)
		needcleanup = true
	end
	type = setting "server_type"
	address = setting "server_address"
end

do
	local fs = require "bee.filesystem"
	local function app_path(name)
		if platform.os == "ios" then
			local ios = require "ios"
			return fs.path(ios.directory(ios.NSDocumentDirectory))
		elseif platform.os == 'windows' then
			return fs.path(os.getenv "LOCALAPPDATA") / name
		elseif platform.os == 'linux' then
			return fs.path(os.getenv "XDG_DATA_HOME" or (os.getenv "HOME" .. "/.local/share")) / name
		elseif platform.os == 'macos' then
			return fs.path(os.getenv "HOME" .. "/Library/Caches") / name
		elseif platform.os == 'android' then
			local android = require "android"
			return fs.path(android.directory(android.ExternalDataPath))
		else
			error "unknown os"
		end
	end
	local root = app_path "ant"
	local repo = root / ".repo"
	if needcleanup then
		fs.remove_all(repo)
	end
	fs.create_directories(repo)
	for i = 0, 255 do
		fs.create_directory(root / ".repo" / ("%02x"):format(i))
	end
	fs.current_path(root)
end

local config = {
	repopath = "./",
	vfspath = "vfs.lua",
	socket = nil,
	nettype = nil,
	address = nil,
	port = nil,
}

if type == nil then
	if platform.os == "ios" or platform.os == "android" then
		type = "usb"
	else
		type = "remote"
		address = "127.0.0.1:2018"
	end
end

if type == "usb" then
	config.nettype = "listen"
	config.address = "127.0.0.1"
	config.port = 2018
elseif type == "remote" then
	config.nettype = "connect"
	local ip, port = address:match "^([^:]+):(%d+)"
	if ip and port then
		config.address = ip
		config.port = port
	else
		config.address = "127.0.0.1"
		config.port = '2018'
	end
elseif type == "offline" then
end

local fw = require "firmware"
local host = {}
local bootloader
local first = true
local quit
function host.update(apis)
	if first then
		first = false
		apis.request("FETCH", "/engine", {
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
end
function host.exit(apis)
	if apis.fd then
		if config.nettype == "listen" then
			config.socket = apis.fd:detach()
		else
			apis.fd:close()
		end
	end
	bootloader = assert(apis.repo:realpath '/engine/firmware/bootloader.lua')
end
assert(fw.loadfile "io.lua")(fw.loadfile, config, host)

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

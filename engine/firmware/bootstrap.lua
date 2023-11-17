__ANT_RUNTIME__ = true

local platform = require "bee.platform"
local fs = require "bee.filesystem"

local config = {
	vfs = {
		slot = 0,
	}
}

local needcleanup, type, address

if platform.os == "ios" then
	local ios = require "ios"
	local clean_up_next_time = ios.setting "clean_up_next_time"
	if clean_up_next_time == true then
		ios.setting("clean_up_next_time", false)
		needcleanup = true
	end
	type = ios.setting "server_type"
	address = ios.setting "server_address"
end

local function app_path(name)
	if platform.os == "windows" then
		return fs.path(os.getenv "LOCALAPPDATA") / name
	elseif platform.os == "linux" then
		return fs.path(os.getenv "XDG_DATA_HOME" or (os.getenv "HOME" .. "/.local/share")) / name
	elseif platform.os == "macos" then
		return fs.path(os.getenv "HOME" .. "/Library/Caches") / name
	else
		error "unknown os"
	end
end

local sandbox_path = (function ()
	if platform.os == "ios" then
		local ios = require "ios"
		return fs.path(ios.directory(ios.NSDocumentDirectory))
	elseif platform.os == "android" then
		local android = require "android"
		return fs.path(android.directory(android.ExternalDataPath))
	else
		return app_path "ant" / "sandbox"
	end
end)()

local bundle_path = (function ()
	if platform.os == "ios" then
		local ios = require "ios"
		return fs.path(ios.bundle())
	elseif platform.os == 'android' then
		local android = require "android"
		return fs.path(android.directory(android.InternalDataPath))
	else
		return app_path "ant" / "bundle"
	end
end)()

config.vfs.bundle_path = (bundle_path / ".vfs"):string():gsub("/?$", "/")
config.vfs.sandbox_path = (sandbox_path / ".vfs"):string():gsub("/?$", "/")
fs.create_directories(sandbox_path)
fs.current_path(sandbox_path)
if needcleanup then
	fs.remove_all(config.vfs.sandbox_path)
end
fs.create_directories(config.vfs.sandbox_path)

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

local _dofile = dofile
function dofile(path)
	local fastio = require "fastio"
    return assert(fastio.loadfile(path))()
end
local i = 1
while true do
    if arg[i] == '-e' then
        i = i + 1
        assert(arg[i], "'-e' needs argument")
        load(arg[i], "=(expr)")()
    elseif arg[i] == nil then
        break
    end
    i = i + 1
end
dofile = _dofile

local boot = require "ltask.bootstrap"
local vfs = require "vfs"
local thread = require "bee.thread"
local socket = require "bee.socket"

thread.newchannel "IOreq"

local s, c = socket.pair()
local io_req = thread.channel "IOreq"
io_req:push(config, s:detach())

vfs.iothread = boot.preinit [[
-- IO thread
local fw = require "firmware"
assert(fw.loadfile "io.lua")()
]]

vfs.initfunc("init_thread.lua", {
	fd = c:detach(),
	editor = __ANT_EDITOR__,
})
dofile "/main.lua"

local name = ...

local ltask = require "ltask"
local vfs = require "vfs"
local ServiceIO = ltask.queryservice "io"
local function call(...)
	return ltask.call(ServiceIO, ...)
end
local function send(...)
	return ltask.send(ServiceIO, ...)
end
vfs.call = call
vfs.send = send
function vfs.read(path)
	return call("READ", path)
end
function vfs.list(path)
	return call("LIST", path)
end
function vfs.type(path)
	return call("TYPE", path)
end
function vfs.resource_setting(setting)
	return call("RESOURCE_SETTING", setting)
end
function vfs.version()
	return call("VERSION")
end
function vfs.directory(what)
	return call("DIRECTORY", what)
end

--TODO: remove they
require "log"
require "filesystem"

local pm = require "packagemanager"
local package, file = name:match "^([^|]*)|(.*)$"
if not package or not file then
	return loadfile(name)
end
return pm.loadenv(package).loadfile("service/"..file..".lua")

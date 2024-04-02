local vfs = require "vfs"

local function readall(path)
	local fastio = require "fastio"
	local mem = vfs.read(path) or error(("`read `%s` failed."):format(path))
	return fastio.tostring(mem)
end

local function init_config(config)
	config.root_initfunc = [[return loadfile "/engine/firmware/ltask_root.lua"]]

	local servicelua = readall "/engine/firmware/ltask_service.lua"
	local dbg = debug.getregistry()["lua-debug"]
	if dbg then
		dbg:event("setThreadName", "Thread: Bootstrap")
		servicelua = table.concat({
			[[local ltask = require "ltask"]],
			[[local name = ("Service:%d <%s>"):format(ltask.self(), ltask.label() or "unk")]],
			[[assert(loadfile '/engine/firmware/debugger.lua')(): event("setThreadName", name): event "wait"]],
			servicelua,
		}, ";")
	end
	config.root.service_source = servicelua
	config.root.service_chunkname = "@/engine/firmware/ltask_service.lua"

	config.root.initfunc = [[
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

]]
end

local m = {}

function m:start(config)
	init_config(config)
	self._obj = dofile "/engine/firmware/ltask_bootstrap.lua"
	self._ctx = self._obj.start(config)
end

function m:wait()
	self._obj.wait(self._ctx)
end

return m

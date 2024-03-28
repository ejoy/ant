local boot = require "ltask.bootstrap"
local vfs = require "vfs"

local SERVICE_ROOT <const> = 1
local MESSSAGE_SYSTEM <const> = 0

local function bootstrap_root(config)
	assert(boot.new_service("root", config.root.service_source, config.root.service_chunkname, SERVICE_ROOT))
	boot.init_root(SERVICE_ROOT)
	local init_msg, sz = boot.pack("init", {
		initfunc = [[return loadfile "/engine/firmware/root.lua"]],
		args = { config.root }
	})
	boot.post_message {
		from = SERVICE_ROOT,
		to = SERVICE_ROOT,
		session = 0,	-- 0 for root init
		type = MESSSAGE_SYSTEM,
		message = init_msg,
		size = sz,
	}
end

local function readall(path)
	local fastio = require "fastio"
	local mem = vfs.read(path) or error(("`read `%s` failed."):format(path))
	return fastio.tostring(mem)
end

local function init_config(config)
	local servicelua = readall "/engine/firmware/service.lua"
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
	config.root.service_chunkname = "@/engine/firmware/service.lua"

	config.root.initfunc = [[
local name = ...

package.path = "/engine/?.lua"
package.cpath = ""
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
function vfs.repopath()
	return call("REPOPATH")
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
	boot.init(config.core)
	boot.init_timer()
	bootstrap_root(config)
	self._ctx = boot.run(config.mainthread)
end

function m:wait()
	boot.wait(self._ctx)
	boot.deinit()
end

return m

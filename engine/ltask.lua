local boot = require "ltask.bootstrap"
local ltask = require "ltask"
local vfs = require "vfs"

local SERVICE_ROOT <const> = 1
local MESSSAGE_SYSTEM <const> = 0

local CoreConfig <const> = 0
local RootConfig <const> = 1
local BootConfig <const> = 2

local ConfigCatalog <const> = {
	worker = CoreConfig,
	queue = CoreConfig,
	queue_sending = CoreConfig,
	max_service = CoreConfig,
	crashlog = CoreConfig,
	debuglog = CoreConfig,
	worker_bind = RootConfig,
	exclusive = RootConfig,
	preinit = RootConfig,
	bootstrap = RootConfig,
	initfunc = RootConfig,
	mainthread = BootConfig
}

local coreConfig
local rootConfig
local bootConfig

local function new_service(label, id)
	local sid = assert(boot.new_service(label, rootConfig.service_source, rootConfig.service_chunkname, id))
	assert(sid == id)
	return sid
end

local function root_thread()
	assert(boot.new_service("root", rootConfig.service_source, rootConfig.service_chunkname, SERVICE_ROOT))
	boot.init_root(SERVICE_ROOT)
	-- send init message to root service
	local initfunc = [[
local name = ...
package.path = nil
package.cpath = ""
local filename, err = package.searchpath(name, "/engine/service/root.lua")
if not filename then
	return nil, err
end
return loadfile(filename)
]]
	local init_msg, sz = ltask.pack("init", {
		initfunc = initfunc,
		name = "root",
		args = {rootConfig}
	})
	-- self bootstrap
	boot.post_message {
		from = SERVICE_ROOT,
		to = SERVICE_ROOT,
		session = 0,	-- 0 for root init
		type = MESSSAGE_SYSTEM,
		message = init_msg,
		size = sz,
	}
end

local function exclusive_thread(label, id)
	local sid = new_service(label, id)
	boot.new_thread(sid)
end

local function io_thread(label, id)
	local sid = assert(boot.new_service_preinit(label, id, vfs.iothread))
	boot.new_thread(sid)
end

local function readall(path)
	local fastio = require "fastio"
	local mem = vfs.read(path)
	return fastio.tostring(mem)
end

local function init(c)
	coreConfig = {}
	rootConfig = {}
	bootConfig = {}
	for k, v in pairs(c) do
		if ConfigCatalog[k] == CoreConfig then
			coreConfig[k] = v
		elseif ConfigCatalog[k] == RootConfig then
			rootConfig[k] = v
		elseif ConfigCatalog[k] == BootConfig then
			bootConfig[k] = v
		else
			assert(false, k)
		end
	end

	local directory = require "directory"
	local log_path = directory.app_path()
	if not coreConfig.debuglog then
		coreConfig.debuglog = (log_path / "debug.log"):string()
	end
	if not coreConfig.crashlog then
		coreConfig.crashlog = (log_path / "crash.log"):string()
	end
	if not coreConfig.worker then
		coreConfig.worker = 6
	end

	rootConfig.bootstrap["ant.ltask|timer"] = {}
	rootConfig.exclusive = rootConfig.exclusive or {}

	local servicelua = readall "/engine/service/service.lua"
	local dbg = debug.getregistry()["lua-debug"]
	if dbg then
		dbg:event("setThreadName", "Thread: Bootstrap")
		servicelua = table.concat({
			[[local ltask = require "ltask"]],
			[[local name = ("Service:%d <%s>"):format(ltask.self(), ltask.label() or "unk")]],
			[[assert(loadfile '/engine/debugger.lua')(): event("setThreadName", name): event "wait"]],
			servicelua,
		}, ";")
	end
	rootConfig.service_source = servicelua
	rootConfig.service_chunkname = "@/engine/service/service.lua"

	rootConfig.initfunc = [[
package.path = "/engine/?.lua"
package.cpath = ""
local ltask = require "ltask"
local vfs = require "vfs"
local fastio = require "fastio"
local thread = require "bee.thread"
local ServiceIO = ltask.uniqueservice "io"
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
	return send("RESOURCE_SETTING", setting)
end
function vfs.version()
	return call("VERSION")
end

local pm = require "packagemanager"
local name = ...
local package, file = name:match "^([^|]*)|(.*)$"
return pm.loadenv(package).loadfile("service/"..file..".lua")

]]
end

local function io_switch()
	local servicelua = "/engine/service/service.lua"
	local mem = vfs.read(servicelua)
	vfs.send("SWITCH", servicelua, mem)
end

local m = {}

function m:start(c)
	init(c)
	boot.init(coreConfig)
	boot.init_timer()
	for i, label in ipairs(rootConfig.exclusive) do
		local id = i + 1
		exclusive_thread(label, id)
	end
	rootConfig.preinit = { "io" }
	root_thread()
	io_switch()
	io_thread("io", 2 + #rootConfig.exclusive)
	self._ctx = boot.run(bootConfig.mainthread)
end

function m:wait()
	boot.wait(self._ctx)
	boot.deinit()
end

local mt = {}
mt.__index = m
function mt:__call(c)
	self:start(c)
	self:wait()
end

return setmetatable({}, mt)

local boot = require "ltask.bootstrap"
local ltask = require "ltask"
local vfs = require "vfs"

local SERVICE_ROOT <const> = 1
local MESSSAGE_SYSTEM <const> = 0

local config

local function new_service(label, id)
	local sid = boot.new_service(label, config.init_service, id)
	assert(sid == id)
	return sid
end

local function root_thread()
	boot.new_service("root", config.init_service, SERVICE_ROOT)
	boot.init_root(SERVICE_ROOT)
	-- send init message to root service
	local init_msg, sz = ltask.pack("init", {
		lua_path = config.lua_path,
		lua_cpath = config.lua_cpath,
		service_path = "/engine/task/service/root.lua",
		name = "root",
		args = {config}
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
	local sid = boot.new_service_preinit(label, id, vfs.iothread)
	boot.new_thread(sid)
end

local function toclose(f)
	return setmetatable({}, {__close=f})
end

local function readall(path)
	local fastio = require "fastio"
	local realpath = vfs.realpath(path)
	return fastio.readall_s(realpath, path)
end

local function init(c)
	config = c
	config.lua_path = nil
	config.lua_cpath = ""
	config.service_path = "${package}/service/?.lua;/engine/task/service/?.lua"

	local servicelua = readall "/engine/task/service/service.lua"

	local initstr = ""

	local dbg = debug.getregistry()["lua-debug"]
	if dbg then
		dbg:event("setThreadName", "Bootstrap")
		initstr = [[
local ltask = require "ltask"
local name = ("Service:%d <%s>"):format(ltask.self(), ltask.label() or "unk")
local function dbg_dofile(filename, ...)
    local f = assert(io.open(filename))
    local str = f:read "a"
    f:close()
    return assert(load(str, "=(debugger.lua)"))(...)
end
local path = os.getenv "LUA_DEBUG_PATH"
dbg_dofile(path .. "/script/debugger.lua", path)
	: attach {}
	: event("setThreadName", name)
	: event "wait"
]]
	end

config.init_service = initstr .. servicelua

	config.preload = [[
package.path = "/engine/?.lua"
local ltask = require "ltask"
local vfs = require "vfs"
local thread = require "bee.thread"
local ServiceIO = ltask.uniqueservice "io"

local function sync_call(cmd, ...)
	local r, _ = thread.rpc_create()
	ltask.send_direct(ServiceIO, "S_"..cmd, r, ...)
	return thread.rpc_wait(r)
end
local function async_call(...)
	return ltask.call(ServiceIO, ...)
end
local function sync_send(cmd, ...)
	local r, _ = thread.rpc_create()
	ltask.send_direct(ServiceIO, "S_"..cmd, r, ...)
end
local function async_send(...)
	return ltask.send(ServiceIO, ...)
end
local call = async_call
local send = async_send
function vfs.switch_sync()
	call = sync_call
	send = sync_send
end
function vfs.switch_async()
	call = async_call
	send = async_send
end
function vfs.realpath(path)
	return call("GET", path)
end
function vfs.list(path)
	return call("LIST", path)
end
function vfs.type(path)
	return call("TYPE", path)
end
function vfs.resource_setting(ext, setting)
	return call("RESOURCE_SETTING", ext, setting)
end
function vfs.call(...)
	return call(...)
end
function vfs.send(...)
	return send(...)
end
local rawsearchpath = package.searchpath
package.searchpath = function(name, path, sep, dirsep)
	local package, file = name:match "^([^|]*)|(.*)$"
	if package and file then
		path = path:gsub("%$%{([^}]*)%}", {
			package = "/pkg/"..package,
		})
		name = file
	else
		path = path:gsub("%$%{([^}]*)%}[^;]*;", "")
	end
	return rawsearchpath(name, path, sep, dirsep)
end

local rawloadfile = loadfile
function loadfile(filename, mode, env)
	if env == nil then
		local package, file = filename:match "^/pkg/([^/]+)/(.+)$"
		if package and file then
			local pm = require "packagemanager"
			return rawloadfile(filename, mode or "bt", pm.loadenv(package))
		end
		return rawloadfile(filename, mode)
	end
	return rawloadfile(filename, mode, env)
end
]]
end

return function (c)
	init(c)
	boot.init(config)
	local _ <close> = toclose(boot.deinit)
	boot.init_timer()
	for i, t in ipairs(config.exclusive) do
		local label = type(t) == "table" and t[1] or t
		local id = i + 1
		exclusive_thread(label, id)
	end
	config.preinit = { "io" }
	root_thread()
	vfs.switch()
	io_thread("io", 2 + #config.exclusive)
	boot.run()
end

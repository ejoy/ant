local boot = require "ltask.bootstrap"
local ltask = require "ltask"

local SERVICE_ROOT <const> = 1
local MESSSAGE_SYSTEM <const> = 0

local config
local init_exclusive_service

local function searchpath(name)
	return assert(package.searchpath(name, config.service_path))
end

local function new_service(label, id)
	local sid = boot.new_service(label, init_exclusive_service, id)
	assert(sid == id)
	return sid
end

local function bootstrap()
	new_service("root", SERVICE_ROOT)
	boot.init_root(SERVICE_ROOT)
	-- send init message to root service
	local init_msg, sz = ltask.pack("init", {
		lua_path = config.lua_path,
		lua_cpath = config.lua_cpath,
		service_path = config.service_path,
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

local function toclose(f)
	return setmetatable({}, {__close=f})
end

local function init(c)
	config = c
	if config.service_path then
		config.service_path = config.service_path .. ";engine/task/service/?.lua"
	else
		config.service_path = "engine/task/service/?.lua"
	end
	config.lua_cpath = config.lua_cpath or package.cpath
	table.insert(config.exclusive, "vfs")

	local initstr = ""
	if __ANT_RUNTIME__ then
	else
		initstr = ([[
package.cpath = %q
require "vfs"
]]):format(package.cpath)
		local dbg = debug.getregistry()["lua-debug"]
		if dbg then
			dbg:event("setThreadName", "Bootstrap")
			initstr = initstr .. [[
local ltask = require "ltask"
local name = ("Service:%d <%s>"):format(ltask.self(), debug.getregistry().SERVICE_LABEL or "unk")
dofile "engine/debugger.lua"
	:event("setThreadName", name)
	:event "wait"
]]
		end
	end

	if config.support_package then
		initstr = initstr .. [[
package.path = "engine/?.lua"
require "bootstrap"

local rawsearchpath = package.searchpath
package.searchpath = function(name, path, sep, dirsep)
	local package, file = name:match "^([^|]*)|(.*)$"
	if package and file then
		path = path:gsub("%$%{([^}]*)%}", {
			package = "/pkg/"..package,
		})
		name = file
	end
	return rawsearchpath(name, path, sep, dirsep)
end

local pm = require "packagemanager"
local rawloadfile = loadfile
function loadfile(filename, mode, env)
	if env == nil then
		local package, file = filename:match "^/pkg/([^/]+)/(.+)$"
		if package and file then
			return loadfile(filename, mode or "bt", pm.loadenv(package))
		end
		return rawloadfile(filename, mode)
	end
	return rawloadfile(filename, mode, env)
end
]]
	end

	local servicelua = searchpath "service"
	init_exclusive_service = initstr .. ([[dofile %q]]):format(servicelua)
	config.init_service = initstr .. ([[
local initfunc = assert(loadfile %q)
local ltask = require "ltask"
local vfs = require "vfs"
local ServiceVfs
local function request(...)
	if not ServiceVfs then
		ServiceVfs = ltask.queryservice "vfs"
	end
	return ltask.call(ServiceVfs, ...)
end
vfs.sync = {realpath=vfs.realpath,list=vfs.list,type=vfs.type,resource=vfs.resource}
function vfs.realpath(path, hash)
	return request("GET", path, hash)
end
function vfs.list(path, hash)
	return request("LIST", path, hash)
end
function vfs.type(path, hash)
	return request("TYPE", path, hash)
end
function vfs.resource(paths)
	return request("RESOURCE", paths)
end
vfs.async = {realpath=vfs.realpath,list=vfs.list,type=vfs.type}
initfunc()]]):format(servicelua)
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
    bootstrap()
    boot.run()
end

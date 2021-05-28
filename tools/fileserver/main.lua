package.path = "engine/?.lua"
require "bootstrap"

local config = {
    service_path = "tools/fileserver/service/?.lua;3rd/ltask/service/?.lua",
    lua_path = "tools/fileserver/lualib/?.lua;3rd/ltask/lualib/?.lua",
    bootstrap = { "listen", arg },
    logger = { "log.server" },
    exclusive = { "timer", "network" },
    --debuglog = "log.txt",
}

local boot = require "ltask.bootstrap"
local ltask = require "ltask"

local SERVICE_ROOT <const> = 1
local MESSSAGE_SYSTEM <const> = 0

local function searchpath(name)
	return assert(package.searchpath(name, config.service_path))
end

local function new_service(id)
	local sid = boot.new_service("@" .. searchpath "service", id)
	assert(sid == id)
	return sid
end

local function bootstrap()
	new_service(SERVICE_ROOT)
	boot.init_root(SERVICE_ROOT)
	-- send init message to root service
	local init_msg, sz = ltask.pack("init", {
		path = config.lua_path,
		cpath = config.lua_cpath,
		filename = searchpath "root",
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

local function exclusive_thread(id)
	local sid = new_service(id)
	boot.new_thread(sid)
end

function print(...)
	boot.pushlog(ltask.pack(...))
end

boot.init(config)
boot.init_timer()

for id = 2, 1 + #config.exclusive do
	exclusive_thread(id)
end

bootstrap()	-- launch root

boot.run()

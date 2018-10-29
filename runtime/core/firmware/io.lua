-- IO Thread

-- todo: Don't use cpath from libs/init.lua
dofile "libs/init.lua"

-- C libs only
local thread = require "thread"
local lsocket = require "lsocket"
local protocol = require "protocol"

local config = {}
local channel = {}
local repo
local connection = {
	request_path = {},	-- request path
	response_hash = {},
	sendq = {},
	recvq = {},
	fd = nil,
	status = "disconnect",
}

local function init_channels()
	-- init channels
	channel.req = thread.channel "IOreq"

	local channel_index = {}
	channel.resp = setmetatable({} , channel_index)

	function channel_index:__index(id)
		assert(type(id) == "number")
		local c = assert(thread.channel("IOresp" .. id))
		self[id] = c
		return c
	end

	local err = thread.channel "errlog"
	function _G.print(...)
		local t = { "[IO]", ... }
		for k,v in ipairs(t) do
			t[k] = tostring(v)
		end
		local str = table.concat( t , "\t" )
		err:push(str)
	end
end

local function init_config()
	local c = channel.req:bpop()
	config.repopath = assert(c.repopath)
	config.address = c.address
	config.port = c.port
	config.firmware = assert(c.firmware)
end

local function init_repo()
	package.path = config.firmware .. "/?.lua"
	local vfs = require "vfs"	-- from firmware
	repo = vfs.new(config.repopath)
end

local function connect_server()
	print("Connect", config.address, config.port)
	local fd, err = lsocket.connect(config.address, config.port)
	if not fd then
		print(err)
		connection.fd = nil
		return
	end
	connection.status = "connecting"
	connection.fd = fd
end

local function work_online()
end

local offline = {}

function offline:GET(path)
	local realpath = repo:realpath(path)
	self:push(realpath)
end

function offline:LIST(path)
	local dir = repo:list(path)
	if dir then
		local result = {}
		for k,v in pairs(dir) do
			result[k] = v.dir
		end
		self:push(result)
	else
		self:push(nil)
	end
end

local function offline_dispatch(id, cmd, ...)
	local f = offline[cmd]
	if not f then
		print("Unsupported command : ", cmd, id)
	else
		f(channel.resp[id], ...)
	end
end

local function work_offline()
	local c = channel.req
	while true do
		offline_dispatch(c:bpop())
	end
end

local function main()
	init_channels()
	init_config()
	init_repo()
	if config.address then
		connect_server()
		work_online()
	else
		work_offline()
	end
end

main()

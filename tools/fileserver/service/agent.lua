local ltask = require "ltask"
local socket = require "socket"
local protocol = require "protocol"

local arg = ltask.call(ltask.queryservice "arguments", "QUERY")
local FD = ...
local REPOPATH = arg[1]

local message = {}
local ServiceCompile
local ServiceLogRuntime
local ServiceDebugProxy
local ServiceVfs = ltask.uniqueservice "vfs"
local VfsSessionId

local function compile_resource(path)
	if not ServiceCompile then
		ServiceCompile = ltask.spawn("compile", REPOPATH)
	end
	return pcall(ltask.call, ServiceCompile, "COMPILE", path)
end

local function response(...)
	socket.send(FD, protocol.packmessage({...}))
end

function message.ROOT(path)
	REPOPATH = assert(REPOPATH or path, "Need repo name")
	print("ROOT", REPOPATH)
	ServiceLogRuntime = ltask.spawn("log.runtime", REPOPATH)
	local sid, roothash = ltask.call(ServiceVfs, "ROOT", REPOPATH)
	VfsSessionId = sid
	response("ROOT", roothash)
end

local function COMPILE(path)
	local ok, lpath = compile_resource(path)
	if not ok then
		response("MISSING", path)
		return
	end
	local hash = ltask.call(ServiceVfs, "BUILD", VfsSessionId, path, lpath)
	response("COMPILE", path, hash)
end

function message.GET(hash)
	if hash:match "%?" then
		COMPILE(hash)
		return
	end
	local filename = ltask.call(ServiceVfs, "GET", VfsSessionId, hash)
	if filename == nil then
		response("MISSING", hash)
		return
	end
	local f = io.open(filename, "rb")
	if not f then
		response("MISSING", hash)
		return
	end
	local sz = f:seek "end"
	f:seek("set", 0)
	if sz < 0x10000 then
		response("BLOB", hash, f:read "a")
	else
		response("FILE", hash, tostring(sz))
		local offset = 0
		while true do
			local data = f:read(0x8000)
			response("SLICE", hash, tostring(offset), data)
			offset = offset + #data
			if offset >= sz then
				break
			end
		end
	end
	f:close()
end

function message.DBG(data)
	--if not ServiceDebugProxy then
	--	ServiceDebugProxy = ltask.spawn("debug.proxy", FD, VfsSessionId)
	--end
	--ltask.send(ServiceDebugProxy, "MESSAGE", data)
end

function message.LOG(data)
	ltask.send(ServiceLogRuntime, "LOG", data)
end

function message.MSG(CMD,...)
end

local function dispatch(fd)
	local reading_queue = {}
	local output = {}
	while true do
		local reading = socket.recv(fd)
		if reading == nil then
			break
		end
		table.insert(reading_queue, reading)
		while true do
			local msg = protocol.readmessage(reading_queue, output)
			if msg == nil then
				break
			end
			local f = message[msg[1]]
			if f then
				f(table.unpack(msg, 2))
			else
				error(msg[1])
			end
		end
	end
end

local function quit()
	if VfsSessionId then
		ltask.send(ServiceVfs, "CLOSE", VfsSessionId)
	end
	if ServiceCompile then
		ltask.send(ServiceCompile, "QUIT")
	end
	if ServiceLogRuntime then
		ltask.send(ServiceLogRuntime, "QUIT")
	end
	if ServiceDebugProxy then
		ltask.send(ServiceDebugProxy, "QUIT")
	end
end

dispatch(FD)
quit()

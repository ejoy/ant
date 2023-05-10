local ltask = require "ltask"
local socket = require "socket"
local protocol = require "protocol"

local FD = ...

local message = {}
local ServiceCompile = ltask.uniqueservice "compile"
local ServiceVfsMgr = ltask.uniqueservice "vfsmgr"
local ServiceLogManager = ltask.uniqueservice "log.manager"
local ServiceEditor = ltask.uniqueservice "editor"
local ServiceDebugProxy

local LoggerIndex, LoggerFile = ltask.call(ServiceLogManager, "CREATE")
local LoggerQueue = {}

ltask.fork(function ()
	while LoggerIndex do
		if #LoggerQueue > 0 then
			local fp <close> = assert(io.open(LoggerFile, 'a'))
			for i = 1, #LoggerQueue do
				local data = LoggerQueue[i]
				LoggerQueue[i] = nil
				fp:write(data)
				fp:write('\n')
			end
		end
		ltask.sleep(1)
	end
end)


local function response(...)
	socket.send(FD, protocol.packmessage({...}))
end

local roothash = ltask.call(ServiceVfsMgr, "ROOT")

function message.SHAKEHANDS()
end

function message.ROOT()
	response("ROOT", roothash)
end

function message.RESOURCE(path)
	local ok, lpath = pcall(ltask.call, ServiceCompile, "COMPILE", path)
	if not ok then
		if type(lpath) == "table" then
			print(table.concat(lpath, "\n"))
		else
			print(lpath)
		end
		response("MISSING", path)
		return
	end
	local hash = ltask.call(ServiceVfsMgr, "BUILD", lpath)
	response("RESOURCE", path, hash)
end

function message.RESOURCE_SETTING(ext, setting)
	ltask.call(ServiceCompile, "SETTING", ext, setting)
end

function message.GET(hash)
	local filename = ltask.call(ServiceVfsMgr, "GET", hash)
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

function message.FETCH(path)
	local hashs = ltask.call(ServiceVfsMgr, "FETCH", path)
	if not hashs then
		response("MISSING", path)
		return
	end
	response("FETCH", path, hashs)
end

function message.FETCH_PATH(session, hash, path)
	local hashs, resource_hashs, unsolved_hashs, error_hashs = ltask.call(ServiceVfsMgr, "FETCH_PATH", hash, path)
	response("FECTH_RESPONSE", session, hashs, resource_hashs, unsolved_hashs, error_hashs)
end

function message.FETCH_DIR(session, hash, path)
	local hashs, resource_hashs, unsolved_hashs, error_hashs = ltask.call(ServiceVfsMgr, "FETCH_DIR", hash, path)
	response("FECTH_RESPONSE", session, hashs, resource_hashs, unsolved_hashs, error_hashs)
end

function message.DBG(data)
	--if not ServiceDebugProxy then
	--	ServiceDebugProxy = ltask.spawn("debug.proxy", FD)
	--end
	--ltask.send(ServiceDebugProxy, "MESSAGE", data)
end

function message.LOG(data)
	ltask.send(ServiceEditor, "MESSAGE", "LOG", "RUNTIME", data)
    LoggerQueue[#LoggerQueue+1] = data
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
	ltask.call(ServiceLogManager, "CLOSE", LoggerIndex)
	if ServiceDebugProxy then
		ltask.send(ServiceDebugProxy, "QUIT")
	end
end

ltask.fork(function()
	dispatch(FD)
	quit()
	ltask.quit()
end)

return {}

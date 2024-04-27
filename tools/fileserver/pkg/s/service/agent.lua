local ltask = require "ltask"
local socket = require "socket"
local protocol = require "protocol"
local serialization = require "bee.serialization"

local FD = ...

local quit = false
local message = {}
local ServiceDebugProxy
local ServiceVfsMgr = ltask.queryservice "s|vfsmgr"
local ServiceLogManager = ltask.uniqueservice "s|log/manager"
local ServiceEditor = ltask.uniqueservice "s|editor"
local CompileId

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
		ltask.wait(LoggerQueue)
	end
end)


local function response(...)
	if socket.send(FD, string.pack("<s2", serialization.packstring(...))) == nil then
		quit = true
	end
end

local function response_ex(tunnel_name, port, session, req)
	local len = #req
	while true do
		if len <= 0x8000 then
			response(tunnel_name, port, session, req)
			break
		else
			response(tunnel_name, port, session, req:sub(1, 0x8000))
			req = req:sub(0x8001)
			len = len - 0x8000
		end
	end
end

local roothash = ltask.call(ServiceVfsMgr, "ROOT")

local TUNNEL_SERVICE = {}

local function new_tunnel(port)
	local TUNNEL_ADDR <const> = "127.0.0.1"
	print("Listen on", TUNNEL_ADDR , port)
	local fd, err = socket.bind("tcp", TUNNEL_ADDR, port)
	if fd then
		return ltask.spawn("s|tunnel", fd)
	else
		print(err)
	end
end

local function tunnel_redirect(port, s, tunnel_name)
	port = tostring(port)
	while true do
		local session, req = ltask.call(s, "REQUEST")
		session = tostring(session)
		if req then
			response_ex(tunnel_name, port, session, req)
		else
			-- session closed
			response(tunnel_name, port, session)
		end
	end
end

-- device use TUNNEL_OPEN (through the fileserver) to open a tunnel
-- fileserver response the request with port and session from client to the device.
function message.TUNNEL_OPEN(port, tunnel_name)
	port = tonumber(port)
	assert(TUNNEL_SERVICE[port] == nil)
	local s = new_tunnel(port)
	if s then
		TUNNEL_SERVICE[port] = s
		ltask.fork(tunnel_redirect, port, s, tunnel_name)
	end
end

-- device use TUNNEL_RESP to response the REQUEST from client before.
-- resp == "" means close the session
function message.TUNNEL_RESP(port, session, resp)
	port = tonumber(port)
	session = tonumber(session)
	local s = TUNNEL_SERVICE[port]
	if s then
		if resp == nil then
			ltask.send(s, "RESPONSE", session)
		else
			ltask.send(s, "RESPONSE", session, resp)
		end
	else
		print("No tunnel service for port", port)
	end
end

local convert = require "converdbgpath"
local function pathToLocal(path)
	return ltask.call(ServiceVfsMgr, "REALPATH", path)
end
local function pathToDA(path)
	return ltask.call(ServiceVfsMgr, "VIRTUALPATH", path)
end

local function debugger_redirect(port, s, tunnel_name)
	port = tostring(port)
	while true do
		local session, req = ltask.call(s, "REQUEST")
		session = tostring(session)
		if req then
			local msg = convert.convertRecv(pathToDA, req)
			while msg do
				response_ex(tunnel_name, port, session, msg)
				msg = convert.convertRecv(pathToDA, "")
			end
		else
			-- session closed
			response(tunnel_name, port, session)
		end
	end
end

function message.DEBUGGER_OPEN(port, tunnel_name)
	port = tonumber(port)
	assert(TUNNEL_SERVICE[port] == nil)
	local s = new_tunnel(port)
	if s then
		TUNNEL_SERVICE[port] = s
		ltask.fork(debugger_redirect, port, s, tunnel_name)
	end
end

function message.DEBUGGER_RESP(port, session, resp)
	port = tonumber(port)
	session = tonumber(session)
	local s = TUNNEL_SERVICE[port]
	if s then
		if resp == nil then
			ltask.send(s, "RESPONSE", session)
		else
			ltask.send(s, "RESPONSE", session, convert.convertSend(pathToLocal, resp))
		end
	else
		print("No tunnel service for port", port)
	end
end

function message.SHAKEHANDS()
end

function message.ROOT()
	response("ROOT", roothash)
end

function message.RESOURCE_SETTING(setting)
	CompileId = ltask.call(ServiceVfsMgr, "RESOURCE_SETTING", setting)
	ltask.fork(function ()
		print("RESOURCE SYNC BEGIN")
		ltask.call(ServiceVfsMgr, "RESOURCE_VERIFY", CompileId)
		print("RESOURCE SYNC DONE")
	end)
end

function message.RESOURCE(path)
	local hash = ltask.call(ServiceVfsMgr, "RESOURCE", CompileId, path)
	if hash then
		response("RESOURCE", path, hash)
	else
		response("MISSING", path)
	end
end

function message.GET(hash)
	local v = ltask.call(ServiceVfsMgr, "GET", hash)
	if not v then
		response("MISSING", hash)
	elseif v.dir then
		local content = v.dir
		local sz = #content
		if sz < 0x8000 then
			response("BLOB", hash, content)
		else
			response("FILE", hash, tostring(sz))
			local offset = 0
			while true do
				local data = content:sub(offset+1, offset+0x8000)
				response("SLICE", hash, tostring(offset), data)
				offset = offset + #data
				if offset >= sz then
					break
				end
			end
		end
	else
		local f = io.open(v.path, "rb")
		if not f then
			response("MISSING", hash)
			return
		end
		local sz = f:seek "end"
		f:seek("set", 0)
		if sz < 0x8000 then
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
end

function message.LOG(data)
	ltask.send(ServiceEditor, "MESSAGE", "LOG", "RUNTIME", data)
	LoggerQueue[#LoggerQueue+1] = data
	if #LoggerQueue == 1 then
		ltask.wakeup(LoggerQueue)
	end
end

local ignore_log = {
	LOG = true,
	TUNNEL_RESP = true,
}

local function dispatch_netmsg(cmd, ...)
	local f = message[cmd]
	if f then
		if not ignore_log[cmd] then
			print(cmd, ...)
		end
		f(...)
	else
		error(cmd)
	end
end

local function dispatch(fd)
	local reading_queue = {}
	while not quit do
		local reading = socket.recv(fd)
		if reading == nil then
			break
		end
		table.insert(reading_queue, reading)
		while true do
			local msg = protocol.readchunk(reading_queue)
			if msg == nil then
				break
			end
			dispatch_netmsg(serialization.unpack(msg))
		end
	end
end

local function quit()
	ltask.call(ServiceVfsMgr, "QUIT", roothash)
	socket.close(FD)
	ltask.call(ServiceLogManager, "CLOSE", LoggerIndex)
	if ServiceDebugProxy then
		ltask.send(ServiceDebugProxy, "QUIT")
	end
	for _, s in pairs(TUNNEL_SERVICE) do
		ltask.send(s, "QUIT")
	end
end

ltask.fork(function()
	dispatch(FD)
	quit()
	ltask.quit()
end)

return {}

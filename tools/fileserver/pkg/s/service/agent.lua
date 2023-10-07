local ltask = require "ltask"
local socket = require "socket"
local protocol = require "protocol"
local fs = require "bee.filesystem"

local FD = ...

local message = {}
local ServiceDebugProxy
local ServiceVfsMgr = ltask.queryservice "s|vfsmgr"
local ServiceLogManager = ltask.uniqueservice "s|log.manager"
local ServiceEditor = ltask.uniqueservice "s|editor"
local ServiceArguments = ltask.queryservice "s|arguments"
local arg = ltask.call(ServiceArguments, "QUERY")
local REPOPATH = fs.absolute(arg[1]):lexically_normal():string()
local ServiceCompile = ltask.uniqueservice("ant.compile_resource|compile", REPOPATH)

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
			local len = #req
			local from = 1
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
		if resp == "" then
			ltask.send(s, "RESPONSE", session)
		else
			ltask.send(s, "RESPONSE", session, resp)
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
	--	ServiceDebugProxy = ltask.spawn("s|debug.proxy", FD)
	--end
	--ltask.send(ServiceDebugProxy, "MESSAGE", data)
end

function message.LOG(data)
	ltask.send(ServiceEditor, "MESSAGE", "LOG", "RUNTIME", data)
    LoggerQueue[#LoggerQueue+1] = data
end

function message.MSG(CMD,...)
end

local ignore_log = {
	LOG = true,
	TUNNEL_RESP = true,
}

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
				if not ignore_log[msg[1]] then
					print(table.unpack(msg))
				end
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

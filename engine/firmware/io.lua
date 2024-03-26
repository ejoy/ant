local path = os.getenv "LUA_DEBUG_PATH"
if path then
	local function load_dbg()
		if path:match "debugger%.lua$" then
			local f = assert(io.open(path))
			local str = f:read "a"
			f:close()
			return assert(load(str, "=(debugger.lua)"))(path)
		end
		return assert(loadfile "/engine/firmware/debugger.lua", "=(debugger.lua)")()
	end
	load_dbg()
		: attach {}
		: event("setThreadName", "Thread: IO")
		: event "wait"
end

local thread = require "bee.thread"
local socket = require "bee.socket"
local platform = require "bee.platform"
local serialization = require "bee.serialization"
local protocol = require "protocol"
local ltask = require "ltask"

local bee_select = require "bee.select"
local selector = bee_select.create()
local SELECT_READ <const> = bee_select.SELECT_READ
local SELECT_WRITE <const> = bee_select.SELECT_WRITE

local config = ...

local OFFLINE = false

local LOG; do
	local fs = require "bee.filesystem"
	local AppPath
	if platform.os == "ios" then
		local ios = require "ios"
		AppPath = fs.path(ios.directory(ios.NSDocumentDirectory)):string()
	elseif platform.os == 'android' then
		local android = require "android"
		AppPath = fs.path(android.directory(android.ExternalDataPath)):string()
	else
		AppPath = fs.current_path():string()
	end
	local logfile = AppPath .. "/io_thread.log"
	fs.create_directories(AppPath)
	if fs.exists(logfile) then
		fs.rename(logfile, AppPath .. "/io_thread_1.log")
	end
	local function LOGRAW(data)
		io.write(data.."\n")
		local f <close> = io.open(logfile, "a+")
		if f then
			f:write(data)
			f:write("\n")
		end
	end

	local origin = os.time() - os.clock()
	local function os_date(fmt)
		local ti, tf = math.modf(origin + os.clock())
		return os.date(fmt, ti):gsub('{ms}', ('%03d'):format(math.floor(tf*1000)))
	end
	local function round(x, increment)
		increment = increment or 1
		x = x / increment
		return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
	end
	local function packstring(...)
		local t = {}
		for i = 1, select('#', ...) do
			local x = select(i, ...)
			if math.type(x) == 'float' then
				x = round(x, 0.01)
			end
			t[#t + 1] = tostring(x)
		end
		return table.concat(t, '\t')
	end
	function LOG(...)
		local info = debug.getinfo(2, 'Sl')
		local text = ('[%s][IO   ](%s:%3d) %s'):format(os_date('%Y-%m-%d %H:%M:%S:{ms}'), info.short_src, info.currentline, packstring(...))
		LOGRAW(text)
	end
end

thread.setname "ant - IO thread"

local vfs = assert(loadfile "/engine/firmware/vfs.lua")()
local repo = vfs.new(config.vfs)

local connection = {
	request = {},
	sendq = {},
	recvq = {},
	fd = nil,
	flags = 0,
}

local function connection_send(...)
	local pack = string.pack("<s2", serialization.packstring(...))
	table.insert(connection.sendq, 1, pack)
end

local function connect_server(address, port)
	LOG("Connecting", address, port)
	local fd, err = socket "tcp"
	if not fd then
		LOG("[ERROR]: "..err)
		return
	end
	local ok
	ok, err = fd:connect(address, port)
	if ok == nil then
		fd:close()
		LOG("[ERROR]: "..err)
		return
	end
	if ok == false then
		selector:event_add(fd, SELECT_WRITE)
		selector:wait()
		selector:event_del(fd)
	end
	local ok, err = fd:status()
	if not ok then
		fd:close()
		LOG("[ERROR]: "..err)
		return
	end
	LOG("Connected")
	return fd
end

local function listen_server(address, port)
	LOG("Listening", address, port)
	local fd, err = socket "tcp"
	if not fd then
		LOG("[ERROR] socket: "..err)
		return
	end
	fd:option("reuseaddr", 1)
	local ok
	ok, err = fd:bind(address, port)
	if not ok then
		LOG("[ERROR] bind: "..err)
		return
	end
	ok, err = fd:listen()
	if not ok then
		LOG("[ERROR] listen: "..err)
		return
	end
	selector:event_add(fd, SELECT_READ)
	local quit
	while not quit do
		quit = true
		for _ in selector:wait(2) do
			local newfd, err = fd:accept()
			if newfd == nil then
				selector:event_del(fd)
				fd:close()
				LOG("[ERROR] accept: "..err)
				return
			elseif newfd == false then
				quit = false
			else
				LOG("Accepted")
				selector:event_del(fd)
				fd:close()
				return newfd
			end
		end
	end
	LOG("[ERROR] select: timeout")
	selector:event_del(fd)
	fd:close()
end

local function wait_server()
	if config.nettype == nil then
		return
	end
	if config.nettype == "listen" then
		return listen_server(config.address, tonumber(config.port))
	end
	if config.nettype == "connect" then
		return connect_server(config.address, tonumber(config.port))
	end
end

local function response_id(id, ...)
	if id then
		ltask.wakeup(id, ...)
	end
end

local function response_err(id, msg)
	LOG("[ERROR]", msg)
	response_id(id)
end

local CMD = {}

local function request_send(...)
	if OFFLINE then
		return
	end
	connection_send(...)
end

local function request_start_with_token(req, args, token, promise)
	if OFFLINE then
		LOG("[ERROR] " .. req .. " failed in offline mode.")
		promise.reject()
		return
	end
	local list = connection.request[token]
	if list then
		list[#list+1] = promise
	else
		connection.request[token] = { promise }
		connection_send(req, args)
	end
end

local function request_start(req, args, promise)
	request_start_with_token(req, args, args, promise)
end

local function request_resolve(args, ...)
	local list = connection.request[args]
	if not list then
		return
	end
	connection.request[args] = nil
	for _, promise in ipairs(list) do
		promise.resolve(args, ...)
	end
end

local function request_reject(args, err)
	local list = connection.request[args]
	if not list then
		return
	end
	connection.request[args] = nil
	for _, promise in ipairs(list) do
		promise.reject(args, err)
	end
end

local function request_file(id, req, hash, res, path)
	local promise = {
		resolve = function ()
			CMD[res](id, path)
		end,
		reject = function ()
			local errmsg = "MISSING "
			if type(path) == "table" then
				errmsg = errmsg .. table.concat(path, " ")
			else
				errmsg = errmsg .. path
			end
			response_err(id, errmsg)
		end
	}
	request_start(req, hash, promise)
end

local NETWORK = {}

function NETWORK.ROOT(hash)
	if hash == '' then
		LOG("[ERROR] INVALID ROOT")
		os.exit(-1, true)
		return
	end
	LOG("[response] ROOT", hash)
	local resources = repo:init(hash)
	for path in pairs(resources) do
		CMD.LIST(nil, path)
	end
	ltask.multi_wakeup "ROOT"
end

-- REMARK: Main thread may reading the file while writing, if file server update file.
-- It's rare because the file name is sha1 of file content. We don't need update the file.
-- Client may not request the file already exist.
function NETWORK.BLOB(hash, data)
	LOG("[response] BLOB", hash, #data)
	if repo:write_blob(hash, data) then
		request_resolve(hash)
	end
end

function NETWORK.FILE(hash, size)
	LOG("[response] FILE", hash, size)
	repo:write_file(hash, size)
end

function NETWORK.MISSING(hash)
	LOG("[response] MISSING", hash)
	request_reject(hash, "MISSING "..hash)
end

function NETWORK.SLICE(hash, offset, data)
	LOG("[response] SLICE", hash, offset, #data)
	if repo:write_slice(hash, offset, data) then
		request_resolve(hash)
	end
end

function NETWORK.RESOURCE(fullpath, hash)
	LOG("[response] RESOURCE", fullpath, hash)
	repo:add_resource(fullpath, hash)
	request_resolve(fullpath)
end

local ListNeedGet <const> = 3
local ListNeedResource <const> = 4

function CMD.LIST(id, fullpath)
	--LOG("[request] LIST", path)
	local dir, r, hash = repo:list(fullpath)
	if dir then
		response_id(id, dir)
		return
	end
	if r == ListNeedGet then
		request_file(id, "GET", hash, "LIST", fullpath)
		return
	end
	if r == ListNeedResource then
		request_file(id, "RESOURCE", hash, "LIST", fullpath)
		return
	end
	response_id(id)
end

function CMD.TYPE(id, fullpath)
	--LOG("[request] TYPE", fullpath)
	if fullpath == "/" then
		response_id(id, "dir")
		return
	end
	local path, name = fullpath:match "^(.*/)([^/]*)$"
	local dir, r, hash = repo:list(path)
	if dir then
		local v = dir[name]
		if not v then
			response_id(id)
		elseif v.type == 'f' then
			response_id(id, "file")
		else
			response_id(id, "dir")
		end
		return
	end

	if r == ListNeedGet then
		request_file(id, "GET", hash, "TYPE", fullpath)
		return
	end
	if r == ListNeedResource then
		request_file(id, "RESOURCE", hash, "TYPE", fullpath)
		return
	end
	response_id(id)
end

function CMD.READ(id, fullpath)
	local path, name = fullpath:match "^(.*/)([^/]*)$"
	local dir, r, hash = repo:list(path)
	if not dir then
		if r == ListNeedGet then
			request_file(id, "GET", hash, "READ", fullpath)
			return
		end
		if r == ListNeedResource then
			request_file(id, "RESOURCE", hash, "READ", fullpath)
			return
		end
		response_err(id, "Not exist path: " .. path)
		return
	end

	local v = dir[name]
	if not v then
		response_err(id, "Not exist file: " .. fullpath)
		return
	end
	if v.type ~= 'f' then
		response_err(id, "Not a file: " .. fullpath)
		return
	end
	local data = repo:open(v.hash)
	if data then
		response_id(id, data, fullpath)
	else
		request_file(id, "GET", v.hash, "READ", fullpath)
	end
end

local function dispatch_net(cmd, ...)
	local f = NETWORK[cmd]
	if not f then
		LOG("[ERROR] Unsupport net command", cmd)
		return
	end
	f(...)
end

local S = {}; do
	local session = 0
	for v, func in pairs(CMD) do
		S[v] = function (...)
			if repo.root == nil then
				ltask.multi_wait "ROOT"
			end
			session = session + 1
			ltask.fork(func, session, ...)
			return ltask.wait(session)
		end
	end
end

function S.RESOURCE_SETTING(setting)
	--LOG("[request] RESOURCE_SETTING", setting)
	repo:resource_setting(setting)
	request_send("RESOURCE_SETTING", setting)
end

function S.VERSION()
	return repo.root or "RUNTIME"
end

function S.quit()
	ltask.quit()
end

function S.SEND(...)
	request_send(...)
end

function S.REDIRECT(resp_command, service_id)
	NETWORK[resp_command] = function(...)
		ltask.send(service_id, resp_command, ...)
	end
end

function S.PATCH(code, data)
	local f = assert(load(code))
	f(data)
end

local function work_offline()
	repo:init()
	local uncomplete_req = {}
	for hash in pairs(connection.request) do
		table.insert(uncomplete_req, hash)
	end
	for _, hash in ipairs(uncomplete_req) do
		request_reject(hash, "UNCOMPLETE "..hash)
	end
	LOG("Working offline")
	ltask.multi_wakeup "ROOT"
end

local function work_online()
	request_send("SHAKEHANDS")
	request_send("ROOT")
end

local function init_event()
	local reading = connection.recvq
	local sending = connection.sendq
	local function read_fd(fd)
		while true do
			local data, err = fd:recv()
			if data == nil then
				if err then
					return nil, err
				end
				return nil, "Closed by remote"
			elseif data == false then
				return true
			end
			table.insert(reading, data)
			while true do
				local msg = protocol.readchunk(reading)
				if not msg then
					break
				end
				dispatch_net(serialization.unpack(msg))
			end
		end
	end
	local function write_fd(fd)
		while true do
			local data = table.remove(sending)
			if data == nil then
				return true
			end
			local nbytes, err = fd:send(data)
			if nbytes == nil then
				return nil, err
			elseif nbytes == false then
				table.insert(sending, data)
				return true
			else
				if nbytes < #data then
					table.insert(sending, data:sub(nbytes+1))
					return true
				end
			end
		end
	end
	local function update_fd(event)
		if event & SELECT_READ ~= 0 then
			if not read_fd(connection.fd) then
				connection.flags = connection.flags & (~SELECT_READ)
				if connection.flags == 0 then
					selector:event_del(connection.fd)
					socket.close(connection.fd)
					connection.fd = nil
					work_offline()
				end
			end
		end
		if event & SELECT_WRITE ~= 0 then
			if not write_fd(connection.fd) then
				connection.flags = connection.flags & (~SELECT_WRITE)
				if connection.flags == 0 then
					selector:event_del(connection.fd)
					socket.close(connection.fd)
					connection.fd = nil
					work_offline()
				end
			end
		end
	end
	connection.flags = SELECT_READ | SELECT_WRITE
	selector:event_add(connection.fd, SELECT_READ | SELECT_WRITE, update_fd)
end


do
	local waitfunc, fd = ltask.eventinit()
	selector:event_add(socket.fd(fd), SELECT_READ, waitfunc)
end

ltask.idle_handler(function()
	if connection.fd then
		local sending = connection.sendq
		if #sending > 0  then
			selector:event_mod(connection.fd, connection.flags)
		else
			selector:event_mod(connection.fd, connection.flags & (~SELECT_WRITE))
		end
	end
	for func, event in selector:wait() do
		func(event)
	end
end)

ltask.fork(function ()
	connection.fd = wait_server()
	if connection.fd then
		init_event()
		work_online()
	else
		work_offline()
	end
end)

return S

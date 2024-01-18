local fw = require "firmware"

local path = os.getenv "LUA_DEBUG_PATH"
if path then
	local function load_dbg()
		if path:match "debugger%.lua$" then
			local f = assert(io.open(path))
			local str = f:read "a"
			f:close()
			return assert(load(str, "=(debugger.lua)"))(path)
		end
		return assert(fw.loadfile "debugger.lua", "=(debugger.lua)")()
	end
	load_dbg()
		: attach {}
		: event("setThreadName", "Thread: IO")
		: event "wait"
end

-- C libs only
local fastio = require "fastio"
local thread = require "bee.thread"
local socket = require "bee.socket"
local platform = require "bee.platform"
local serialization = require "bee.serialization"
local protocol = require "protocol"
local exclusive = require "ltask.exclusive"
local ltask

local bee_select = require "bee.select"
local selector = bee_select.create()
local SELECT_READ <const> = bee_select.SELECT_READ
local SELECT_WRITE <const> = bee_select.SELECT_WRITE

local io_req = thread.channel "IOreq"
local config, fddata = io_req:bpop()

local QUIT = false
local OFFLINE = false

local _print = _G.print
if platform.os == 'android' then
	local android = require "android"
	_print = function (text)
		android.rawlog("info", "IO", text)
	end
end

local channelfd = socket.fd(fddata)
local channelfd_init = false

thread.setname "ant - IO thread"

local vfs = assert(fw.loadfile "vfs.lua")()
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

local function init_channels()
	io_req = thread.channel "IOreq"

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
	function _G.print(...)
		local info = debug.getinfo(2, 'Sl')
		local text = ('[%s][IO   ](%s:%3d) %s'):format(os_date('%Y-%m-%d %H:%M:%S:{ms}'), info.short_src, info.currentline, packstring(...))
		if OFFLINE then
			_print(text)
		else
			connection_send("LOG", text)
		end
	end
end

local function connect_server(address, port)
	print("Connecting", address, port)
	local fd, err = socket "tcp"
	if not fd then
		_print("[ERROR]: "..err)
		return
	end
	local ok
	ok, err = fd:connect(address, port)
	if ok == nil then
		fd:close()
		_print("[ERROR]: "..err)
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
		_print("[ERROR]: "..err)
		return
	end
	print("Connected")
	return fd
end

local function listen_server(address, port)
	print("Listening", address, port)
	local fd, err = socket "tcp"
	if not fd then
		_print("[ERROR] socket: "..err)
		return
	end
	fd:option("reuseaddr", 1)
	local ok
	ok, err = fd:bind(address, port)
	if not ok then
		_print("[ERROR] bind: "..err)
		return
	end
	ok, err = fd:listen()
	if not ok then
		_print("[ERROR] listen: "..err)
		return
	end
	selector:event_add(fd, SELECT_READ)
	for _ in selector:wait(2) do
		local newfd, err = fd:accept()
		if not newfd then
			selector:event_del(fd)
			fd:close()
			_print("[ERROR] accept: "..err)
			return
		end
		print("Accepted")
		selector:event_del(fd)
		fd:close()
		return newfd
	end
	_print("[ERROR] select: timeout")
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

-- response io request with id
local function response_id(id, ...)
	if id then
		assert(type(id) ~= "string")
		thread.rpc_return(id, ...)
	end
end

local function response_err(id, msg)
	print("[ERROR]", msg)
	response_id(id, nil)
end

local CMD = {}


local function schedule_message()
	local SCHEDULE_IDLE <const> = 1
	while true do
		local s = ltask.schedule_message()
		if s == SCHEDULE_IDLE then
			break
		end
		coroutine.yield()
	end
end

local function event_select(timeout)
	if connection.fd then
		local sending = connection.sendq
		if #sending > 0  then
			selector:event_mod(connection.fd, connection.flags)
		else
			selector:event_mod(connection.fd, connection.flags & (~SELECT_WRITE))
		end
	end
	for func, event in selector:wait(timeout) do
		func(event)
	end
	if ltask then
		schedule_message()
	end
end

local function request_send(...)
	if OFFLINE then
		return
	end
	connection_send(...)
end

local function request_start_with_token(req, args, token, promise)
	if OFFLINE then
		print("[ERROR] " .. req .. " failed in offline mode.")
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

-- response functions from file server (connection)
local response = {}

function response.ROOT(hash)
	if hash == '' then
		_print("[ERROR] INVALID ROOT")
		os.exit(-1, true)
		return
	end
	print("[response] ROOT", hash)
	local resources = repo:init(hash)
	for path in pairs(resources) do
		CMD.LIST(nil, path)
	end
end

-- REMARK: Main thread may reading the file while writing, if file server update file.
-- It's rare because the file name is sha1 of file content. We don't need update the file.
-- Client may not request the file already exist.
function response.BLOB(hash, data)
	print("[response] BLOB", hash, #data)
	if repo:write_blob(hash, data) then
		request_resolve(hash)
	end
end

function response.FILE(hash, size)
	print("[response] FILE", hash, size)
	repo:write_file(hash, size)
end

function response.MISSING(hash)
	print("[response] MISSING", hash)
	request_reject(hash, "MISSING "..hash)
end

function response.SLICE(hash, offset, data)
	print("[response] SLICE", hash, offset, #data)
	if repo:write_slice(hash, offset, data) then
		request_resolve(hash)
	end
end

function response.RESOURCE(fullpath, hash)
	print("[response] RESOURCE", fullpath, hash)
	repo:add_resource(fullpath, hash)
	request_resolve(fullpath)
end

local ListNeedGet <const> = 3
local ListNeedResource <const> = 4

function CMD.LIST(id, fullpath)
	fullpath = fullpath:gsub("|", "/")
--	print("[request] LIST", path)
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
	response_id(id, nil)
end

function CMD.TYPE(id, fullpath)
	fullpath = fullpath:gsub("|", "/")
	--	print("[request] TYPE", fullpath)
	if fullpath == "/" then
		response_id(id, "dir")
		return
	end
	local path, name = fullpath:match "^(.*/)([^/]*)$"
	local dir, r, hash = repo:list(path)
	if dir then
		local v = dir[name]
		if not v then
			response_id(id, nil)
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
	response_id(id, nil)
end

function CMD.READ(id, fullpath)
	fullpath = fullpath:gsub("|", "/")
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
		response_err(id, "Not exist<1> " .. path)
		return
	end

	local v = dir[name]
	if not v then
		response_err(id, "Not exist<2> " .. fullpath)
		return
	end
	if v.type ~= 'f' then
		response_id(id, false, v.hash)
		return
	end
	local data = repo:open(v.hash)
	if data then
		response_id(id, data, fullpath)
	else
		request_file(id, "GET", v.hash, "READ", fullpath)
	end
end

function CMD.RESOURCE_SETTING(_, setting)
--	print("[request] RESOURCE_SETTING", setting)
	repo:resource_setting(setting)
	request_send("RESOURCE_SETTING", setting)
end

function CMD.SEND(_, ...)
	request_send(...)
end

function CMD.VERSION(id)
	response_id(id, repo.root or "RUNTIME")
end

function CMD.quit(id)
	QUIT = true
	response_id(id)
end

-- dispatch package from connection
local function dispatch_net(cmd, ...)
	local f = response[cmd]
	if not f then
		print("[ERROR] Unsupport net command", cmd)
		return
	end
	f(...)
end

local function dispatch(ok, id, cmd, ...)
	if not ok then
		-- no req
		return false
	end
	local f = CMD[cmd]
	if not f then
		print("[ERROR] Unsupported command : ", cmd)
	else
		f(id, ...)
	end
	return true
end

function CMD.REDIRECT(_, resp_command, service_id)
	response[resp_command] = function(...)
		ltask.send(service_id, resp_command, ...)
	end
end

function CMD.REDIRECT_CHANNEL(_, resp_command, channel_name)
	local channel = thread.channel(channel_name)
	response[resp_command] = function(...)
		channel:push(...)
	end
end

local S = {}; do
	local session = 0
	for v in pairs(CMD) do
		S[v] = function (...)
			session = session + 1
			ltask.fork(function (...)
				dispatch(true, ...)
			end, session, v, ...)
			return ltask.wait(session)
		end
	end
	function response_id(id, ...)
		if id then
			assert(type(id) ~= "string")
			if type(id) == "userdata" then
				thread.rpc_return(id, ...)
			else
				ltask.wakeup(id, ...)
			end
		end
	end
end

local function ltask_ready()
	return coroutine.yield() == nil
end

local function ltask_init(path, mem)
	assert(fastio.loadlua(mem, path))(true)
	ltask = require "ltask"
	local SS = ltask.dispatch(S)

	function SS.PATCH(code, data)
		local f = load(code)
		f(data)
	end

	local waitfunc, fd = exclusive.eventinit()
	local ltaskfd = socket.fd(fd)
	local function read_ltaskfd()
		waitfunc()
		local SCHEDULE_IDLE <const> = 1
		while true do
			local s = ltask.schedule_message()
			if s == SCHEDULE_IDLE then
				break
			end
			coroutine.yield()
		end
	end
	selector:event_add(ltaskfd, SELECT_READ, read_ltaskfd)
end

function CMD.SWITCH(_, path, mem)
	while not ltask_ready() do
		exclusive.sleep(1)
	end
	ltask_init(path, mem)
end

local function work_offline()
	OFFLINE = true

	while true do
		event_select()
	end
end

local function work_online()
	request_send("SHAKEHANDS")
	request_send("ROOT")
	while not QUIT do
		event_select()
	end
end


local function init_channelfd()
	if channelfd_init then
		return
	end
	channelfd_init = true
	local function read_channelfd()
		while true do
			local r = channelfd:recv()
			if r == nil then
				selector:event_del(channelfd)
				return
			end
			if r == false then
				return
			end
			while dispatch(io_req:pop()) do
			end
		end
	end
	selector:event_add(channelfd, SELECT_READ, read_channelfd)
end

local function init_event()
	local reqs = {}
	local reading = connection.recvq
	local sending = connection.sendq
	local function dispatch_netmsg(cmd, ...)
		if reqs then
			if cmd ~= "ROOT" then
				table.insert(reqs, {cmd, ...})
			else
				dispatch_net(cmd, ...)
				for _, req in ipairs(reqs) do
					dispatch_net(table.unpack(req))
				end
				reqs = nil
				init_channelfd()
			end
		else
			dispatch_net(cmd, ...)
		end
	end
	local function read_fd(fd)
		local data, err = fd:recv()
		if data == nil then
			if err then
				-- socket error
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
			dispatch_netmsg(serialization.unpack(msg))
		end
		if ltask then
			ltask.dispatch_wakeup()
			coroutine.yield()
		end
		return true
	end
	local function write_fd(fd)
		while true do
			local data = table.remove(sending)
			if data == nil then
				break
			end
			local nbytes, err = fd:send(data)
			if nbytes then
				if nbytes < #data then
					table.insert(sending, data:sub(nbytes+1))
					break
				end
			else
				if err then
					return nil, err
				else
					table.insert(sending, data)	-- push back
				end
				break
			end
		end
		return true
	end
	local function update_fd(event)
		if event & SELECT_READ ~= 0 then
			if not read_fd(connection.fd) then
				connection.flags = connection.flags & (~SELECT_READ)
				if connection.flags == 0 then
					selector:event_del(connection.fd)
					QUIT = true
				end
			end
		end
		if event & SELECT_WRITE ~= 0 then
			if not write_fd(connection.fd) then
				connection.flags = connection.flags & (~SELECT_WRITE)
				if connection.flags == 0 then
					selector:event_del(connection.fd)
					QUIT = true
				end
			end
		end
	end
	connection.flags = SELECT_READ | SELECT_WRITE
	selector:event_add(connection.fd, SELECT_READ | SELECT_WRITE, update_fd)
end

local function main()
	init_channels()
	connection.fd = wait_server()
	if connection.fd then
		init_event()
		work_online()
		-- socket error or closed
	end
	repo:init()
	init_channelfd()
	local uncomplete_req = {}
	for hash in pairs(connection.request) do
		table.insert(uncomplete_req, hash)
	end
	for _, hash in ipairs(uncomplete_req) do
		request_reject(hash, "UNCOMPLETE "..hash)
	end
	if QUIT then
		return
	end
	print("Working offline")
	work_offline()
end

main()

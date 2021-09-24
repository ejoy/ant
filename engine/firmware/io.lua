local loadfile, host = ...

local INTERVAL = 0.01 -- socket select timeout

-- C libs only
local thread = require "thread"
local lsocket = require "lsocket"
local protocol = require "protocol"
local _print

local status = {}
local config = {}
local repo

local channel_req
local channel_user
local logqueue = {}

local connection = {
	request = {},
	sendq = {},
	recvq = {},
	fd = nil,
	subscibe = {},
}

local function init_channels()
	channel_req = thread.channel_consume "IOreq"

	local mt = {}
	function mt:__index(name)
		local c = assert(thread.channel_produce(name))
		self[name] = c
		return c
	end
	channel_user = setmetatable({} , mt)

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
	_print = _G.print
	function _G.print(...)
		local info = debug.getinfo(2, 'Sl')
		logqueue[#logqueue+1] = ('[%s][IO   ](%s:%3d) %s'):format(os_date('%Y-%m-%d %H:%M:%S:{ms}'), info.short_src, info.currentline, packstring(...))
	end
end

local function read_config(path, env)
	env = env or {}
	local r = loadfile(path, "t", env)
	if not r then
		return
	end
	if not pcall(r) then
		return
	end
	return env
end

local function init_config(c)
	config.repopath = assert(c.repopath)
	config.nettype = assert(c.nettype)
	config.address = assert(c.address)
	config.port = assert(c.port)
	config.vfspath = assert(c.vfspath)
	config.rootname = c.rootname
	config.socket = c.socket
	read_config(config.repopath .. "config", config)
end

local function init_repo()
	local vfs = assert(loadfile(config.vfspath, 'engine/firmware/vfs.lua'))()
	repo = vfs.new(config.repopath)
	status.repo = repo
end

local function connect_server(address, port)
	print("Connecting", address, port)
	local fd, err = lsocket.connect(address, port)
	if not fd then
		print("connect:", err)
		return
	end
	local rd,wt = lsocket.select(nil, {fd})
	if not rd then
		print("select:", wt)	-- select error
		fd:close()
		return
	end
	local ok, err = fd:status()
	if not ok then
		fd:close()
		print("status:", err)
		return
	end
	print("Connected")
	return fd
end

local function listen_server(address, port)
	print("Listening", address, port)
	local fd, err = lsocket.bind(address, port)
	if not fd then
		print("bind:", err)
		return
	end
	local rd,wt = lsocket.select({fd}, 1)
	if rd == false then
		print("select:", 'timeout')
		fd:close()
		return
	elseif rd == nil then
		print("select:", wt)	-- select error
		fd:close()
		return
	end
	local newfd, err = fd:accept()
	if not newfd then
		fd:close()
		print("accept:", err)
		return
	end
	print("Accepted")
	return newfd
end

local function wait_server()
	if config.socket then
		return lsocket.fromstring(config.socket)
	end
	if config.nettype == "listen" then
		return listen_server(config.address, config.port)
	end
	if config.nettype == "connect" then
		return connect_server(config.address, config.port)
	end
end

-- response io request with id
local function response_id(id, ...)
	if id then
		if type(id) == "string" then
			local c = thread.channel_produce(id)
			c(...)
		else
			channel_req:ret(id, ...)
		end
	end
end

local function response_err(id, msg)
	print(msg)
	response_id(id, nil, msg)
end

local function logger_dispatch(t)
	for i = 1, #logqueue do
		t.SEND(false, "LOG", logqueue[i])
		logqueue[i] = nil
	end
end

local offline = {}

function offline.LIST(id, path, roothash)
	local dir = repo:list(path, roothash)
	if dir then
		response_id(id, dir)
	else
		response_id(id, nil)
	end
end

function offline.TYPE(id, fullpath, roothash)
	local path, name = fullpath:match "(.*)/(.-)$"
	if path == nil then
		if fullpath == "" then
			response_id(id, "dir")
			return
		end
		path = ""
		name = fullpath
	end
	local dir = repo:list(path, roothash)
	if dir then
		local v = dir[name]
		if v then
			response_id(id, v.dir and "dir" or "file")
			return
		end
	end
	response_id(id, nil)
end

function offline.GET(id, fullpath, roothash)
	local path, name = fullpath:match "(.*)/(.-)$"
	if path == nil then
		path = ""
		name = fullpath
	end
	local dir = repo:list(path, roothash)
	if not dir then
		response_id(id, nil)
		return
	end
	local v = dir[name]
	if not v then
		response_id(id, nil)
		return
	end
	if v.dir then
		response_id(id, false, v.hash)
		return
	end
	local realpath = repo:hashpath(v.hash)
	response_id(id, realpath)
end

function offline.RESOURCE(id, paths)
	if #paths < 2 then
		offline.GET(id, paths[1])
		return
	end
	local hash = repo:get_resource(paths[1])
	if not hash then
		response_id(id, nil)
		return
	end
	for i = 2, #paths-1 do
		local path = table.concat(paths, "/", 1, i) --TODO
		hash = repo:get_resource(path)
		if not hash then
			response_id(id, nil)
			return
		end
	end
	offline.GET(id, paths[#paths], hash)
end

function offline.EXIT(id)
	response_id(id, nil)
	error "EXIT"
end

function offline.SEND(_,msg, ...)
	if msg == "LOG" then
		_print(...)
	end
end

do
	local function noresponse_function() end
	offline.FETCH    = noresponse_function
	offline.SUBSCIBE = noresponse_function
end

local function offline_dispatch(id, cmd, ...)
	local f = offline[cmd]
	if not f then
		print("Unsupported offline command : ", cmd)
	else
		f(id, ...)
	end
end

local function work_offline()
	local c = channel_req
	while true do
		offline_dispatch(c())
		logger_dispatch(offline)
	end
end

local online = {}

local function connection_send(...)
	local pack = protocol.packmessage({...})
	table.insert(connection.sendq, 1, pack)
end

-- fd set for select
local rdset = {}
local wtset = {}
local function connection_dispose(timeout)
	local sending = connection.sendq
	local fd = connection.fd
	local rd, wt
	if #sending > 0  then
		rd, wt = lsocket.select(rdset, wtset, timeout)
	else
		rd, wt = lsocket.select(rdset, timeout)
	end
	if not rd then
		if rd == false then
			-- timeout
			return false
		end
		-- select error
		return nil, wt
	end
	if wt and wt[1] then
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
	end
	if rd[1] then
		local data, err = fd:recv()
		if not data then
			if err then
				-- socket error
				return nil, err
			end
			return nil, "Closed by remote"
		end
		table.insert(connection.recvq, data)
	end
	return true
end

local function request_start(req, args, promise)
	local list = connection.request[args]
	if list then
		list[#list+1] = promise
	else
		connection.request[args] = { promise }
		connection_send(req, args)
	end
end
status.request = request_start

local function request_complete(args, ok, err)
	local list = connection.request[args]
	if not list then
		return
	end
	connection.request[args] = nil
	if ok then
		for _, promise in ipairs(list) do
			promise.resolve(args)
		end
	else
		for _, promise in ipairs(list) do
			promise.reject(args, err)
		end
	end
end

local function request_file(id, req, hash, res, path, roothash)
	local promise = {
		resolve = function ()
			online[res](id, path, roothash)
		end,
		reject = function ()
			if roothash then
				response_err(id, "MISSING "..path.." "..roothash)
			else
				response_err(id, "MISSING "..path)
			end
		end
	}
	request_start(req, hash, promise)
end

-- response functions from file server (connection)
local response = {}

function response.ROOT(hash)
	if hash == '' then
		_print("INVALID ROOT", config.rootname)
		os.exit(-1, true)
		return
	end
	print("CHANGEROOT", hash)
	repo:updatehistory(hash)
	repo:changeroot(hash)
end

-- REMARK: Main thread may reading the file while writing, if file server update file.
-- It's rare because the file name is sha1 of file content. We don't need update the file.
-- Client may not request the file already exist.
function response.BLOB(hash, data)
	if repo:write_blob(hash, data) then
		request_complete(hash, true)
	end
end

function response.FILE(hash, size)
	repo:write_file(hash, size)
end

function response.MISSING(hash)
	print("MISSING", hash)
	request_complete(hash, false)
end

function response.SLICE(hash, offset, data)
	if repo:write_slice(hash, offset, data) then
		request_complete(hash, true)
	end
end

function response.RESOURCE(fullpath, hash)
	repo:set_resource(fullpath, hash)
	print("RESOURCE", fullpath, hash)
	request_complete(fullpath, true)
end

function response.FETCH(path, hashs)
	local waiting = {}
	local missing = {}
	local function finish()
		if next(waiting) == nil then
			local res = {}
			for h in pairs(missing) do
				res[#res+1] = h
			end
			if #res == 0 then
				request_complete(path, true)
			else
				table.insert(res, 1, "MISSING")
				request_complete(path, false, table.concat(res))
			end
		end
	end
	local promise = {
		resolve = function (hash)
			waiting[hash] = nil
			finish()
		end,
		reject = function (hash)
			missing[hash] = true
			waiting[hash] = nil
			finish()
		end
	}
	hashs:gsub("[^|]+", function(hash)
		local realpath = repo:hashpath(hash)
		local f <close> = io.open(realpath, "rb")
		if not f then
			waiting[hash] = true
			request_start("GET", hash, promise)
		end
	end)
	finish()
end

local function waiting_for_root()
	local resp = {}
	local reading = connection.recvq
	connection_send("ROOT", config.rootname)
	while true do
		local ok, err = connection_dispose(INTERVAL)
		if not ok then
			if ok == nil then
				print("dispose", err)
				return
			end
			-- timeout
		else
			local changeroot
			local result = {}
			while protocol.readmessage(reading, result) do
				if result[1] == "ROOT" then
					changeroot = result[2]
				else
					table.insert(resp, result)
					result = {}
				end
			end
			if changeroot then
				response.ROOT(changeroot)
				return resp
			end
		end
	end
end

---------- online dispatch

function online.LIST(id, path, roothash)
	local dir, hash = repo:list(path, roothash)
	if dir then
		response_id(id, dir)
	elseif hash then
		request_file(id, "GET", hash, "LIST", path, roothash)
	else
		print("Need Change Root", roothash, path)
		response_id(id, nil)
	end
end

function online.FETCH(id, path)
	request_start("FETCH", path, {
		resolve = function ()
			response_id(id)
		end,
		reject = function (_, err)
			response_err(id, err)
		end
	})
end

function online.TYPE(id, fullpath, roothash)
	local path, name = fullpath:match "(.*)/(.-)$"
	if path == nil then
		if fullpath == "" then
			response_id(id, "dir")
			return
		end
		path = ""
		name = fullpath
	end
	local dir, hash = repo:list(path, roothash)
	if dir then
		local v = dir[name]
		if not v then
			response_id(id, nil)
		else
			response_id(id, v.dir and "dir" or "file")
		end
		return
	elseif hash then
		request_file(id, "GET", hash, "TYPE", fullpath, roothash)
	else
		response_id(id, nil)
	end
end

function online.GET(id, fullpath, roothash)
	local path, name = fullpath:match "(.*)/(.-)$"
	if path == nil then
		path = ""
		name = fullpath
	end
	local dir, hash = repo:list(path, roothash)
	if not dir then
		if hash then
			request_file(id, "GET", hash, "GET", fullpath, roothash)
			return
		end
		response_err(id, "Not exist<1> " .. path .. (roothash and (" "..roothash) or ""))
		return
	end

	local v = dir[name]
	if not v then
		response_err(id, "Not exist<2> " .. fullpath .. (roothash and (" "..roothash) or ""))
		return
	end
	if v.dir then
		response_id(id, false, v.hash)
		return
	end
	local realpath = repo:hashpath(v.hash)
	local f = io.open(realpath,"rb")
	if not f then
		request_file(id, "GET", v.hash, "GET", fullpath, roothash)
	else
		f:close()
		response_id(id, realpath)
	end
end

function online.RESOURCE(id, paths)
	if #paths < 2 then
		online.GET(id, paths[1])
		return
	end
	local hash = repo:get_resource(paths[1])
	if not hash then
		request_file(id, "RESOURCE", paths[1], "RESOURCE", paths)
		return
	end
	for i = 2, #paths-1 do
		local path = table.concat(paths, "/", 1, i) --TODO
		hash = repo:get_resource(path)
		if not hash then
			request_file(id, "RESOURCE", path, "RESOURCE", paths)
			return
		end
	end
	online.GET(id, paths[#paths], hash)
end

function online.SUBSCIBE(channel_name, message)
	if connection.subscibe[message] then
		print("Duplicate subscibe", message, channel_name)
	end
	connection.subscibe[message] = channel_name
end

function online.SEND(_, ...)
	connection_send(...)
end

function online.EXIT(id)
	response_id(id, nil)
	error "EXIT"
end

-- dispatch package from connection
local function dispatch_net(cmd, ...)
	local f = response[cmd]
	if not f then
		local channel_name = connection.subscibe[cmd]
		if channel_name then
			channel_user[channel_name](cmd, ...)
		else
			print("Unsupport net command", cmd)
		end
		return
	end
	f(...)
end

local function online_dispatch(ok, id, cmd, ...)
	if not ok then
		-- no req
		return false
	end
	local f = online[cmd]
	if not f then
		print("Unsupported online command : ", cmd)
	else
		f(id, ...)
		--local ok, err = xpcall(f, debug.traceback, ...)
		--if not ok then
		--	print(err)
		--end
	end
	return true
end

local function work_online()
	rdset[1] = connection.fd	-- may need support multi socket
	wtset[1] = connection.fd
	local reqs = waiting_for_root()
	if not reqs then
		return
	end
	for _, req in ipairs(reqs) do
		dispatch_net(table.unpack(req))
	end
	local result = {}
	local reading = connection.recvq
	local timeout = 0
	while true do
		if host.update(status, timeout) then
			break
		end
		local ok, err = connection_dispose(0)
		if ok then
			while protocol.readmessage(reading, result) do
				dispatch_net(table.unpack(result))
			end
			timeout = 0
		else
			if ok == nil then
				print("Connection Error", err)
				break
			end
			timeout = timeout + 0.001
			if timeout > INTERVAL then
				timeout = INTERVAL
			end
		end
	end
end

if not host then
	host = {}
	function host.init()
		init_channels()
		local _, c = channel_req()
		return c
	end
	function host.update(_, timeout)
		while online_dispatch(channel_req:pop(timeout)) do end
		logger_dispatch(online)
	end
	function host.exit()
		print("Working offline")
		work_offline()
	end
end

local function main()
	init_config(host.init())
	init_repo()
	if config.address then
		connection.fd = wait_server()
		if connection.fd then
			status.fd = connection.fd
			work_online()
			-- socket error or closed
		end
	end
	local uncomplete_req = {}
	for hash in pairs(connection.request) do
		table.insert(uncomplete_req, hash)
	end
	for _, hash in ipairs(uncomplete_req) do
		request_complete(hash, false)
	end
	host.exit(status)
end

main()

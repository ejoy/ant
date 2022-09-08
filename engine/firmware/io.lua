local loadfile, config, host = ...

local INTERVAL = 0.01 -- socket select timeout

-- C libs only
local thread = require "bee.thread"
local socket = require "bee.socket"
local protocol = require "protocol"
local _print

thread.setname "ant - IO thread"

local status = {}
local repo

local io_req
local logqueue = {}

local connection = {
	request = {},
	sendq = {},
	recvq = {},
	fd = nil,
}

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
	_print = _G.print
	function _G.print(...)
		local info = debug.getinfo(2, 'Sl')
		logqueue[#logqueue+1] = ('[%s][IO   ](%s:%3d) %s'):format(os_date('%Y-%m-%d %H:%M:%S:{ms}'), info.short_src, info.currentline, packstring(...))
	end
end

local function init_repo()
	local vfs = assert(loadfile(config.vfspath))()
	repo = vfs.new(config.repopath)
	status.repo = repo
end

local function connect_server(address, port)
	print("Connecting", address, port)
	local fd, err = socket "tcp"
	if not fd then
		print("[ERROR] socket:", err)
		return
	end
	local ok
	ok, err = fd:connect(address, port)
	if ok == nil then
		fd:close()
		print("[ERROR] connect:", err)
		return
	end
	if ok == false then
		local rd,wt = socket.select(nil, {fd})
		if not rd then
			print("[ERROR] select:", wt)	-- select error
			fd:close()
			return
		end
	end
	local ok, err = fd:status()
	if not ok then
		fd:close()
		print("[ERROR] status:", err)
		return
	end
	print("Connected")
	return fd
end

local function listen_server(address, port)
	print("Listening", address, port)
	local fd, err = socket "tcp"
	if not fd then
		print("[ERROR] socket:", err)
		return
	end
	fd:option("reuseaddr", 1)
	local ok
	ok, err = fd:bind(address, port)
	if not ok then
		print("[ERROR] bind:", err)
		return
	end
	ok, err = fd:listen()
	if not ok then
		print("[ERROR] listen:", err)
		return
	end
	local rd,wt = socket.select({fd}, nil, 2)
	if rd == false then
		print("[ERROR] select:", 'timeout')
		fd:close()
		return
	elseif rd == nil then
		print("[ERROR] select:", wt)	-- select error
		fd:close()
		return
	end
	local newfd, err = fd:accept()
	if not newfd then
		fd:close()
		print("[ERROR] accept:", err)
		return
	end
	print("Accepted")
	return newfd
end

local function wait_server()
	if config.socket then
		return socket.undump(config.socket)
	end
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
	response_id(id, nil, msg)
end

local function logger_dispatch(t)
	for i = 1, #logqueue do
		t.SEND(false, "LOG", logqueue[i])
		logqueue[i] = nil
	end
end

local offline = {}

function offline.LIST(id, path)
	print("[offline] LIST", path)
	local dir = repo:list(path)
	if dir then
		response_id(id, dir)
	else
		response_id(id, nil)
	end
end

function offline.TYPE(id, fullpath)
	print("[offline] TYPE", fullpath)
	local path, name = fullpath:match "(.*)/(.-)$"
	if path == nil then
		if fullpath == "" then
			response_id(id, "dir")
			return
		end
		path = ""
		name = fullpath
	end
	local dir = repo:list(path)
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
	response_id(id, nil)
end

function offline.GET(id, fullpath)
	print("[offline] GET", fullpath)
	local path, name = fullpath:match "(.*)/(.-)$"
	if path == nil then
		path = ""
		name = fullpath
	end
	local dir = repo:list(path)
	if not dir then
		response_id(id, nil)
		return
	end
	local v = dir[name]
	if not v then
		response_id(id, nil)
		return
	end
	if v.type ~= 'f' then
		response_id(id, false, v.hash)
		return
	end
	local realpath = repo:hashpath(v.hash)
	response_id(id, realpath)
end

function offline.RESOURCE_SETTING(_, ext, setting)
	print("[offline] RESOURCE_SETTING", ext, setting)
end

function offline.EXIT(id)
	print("[offline] EXIT")
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
end

local function offline_dispatch(id, cmd, ...)
	local f = offline[cmd]
	if not f then
		print("[ERROR] Unsupported offline command : ", cmd)
	else
		f(id, ...)
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
		rd, wt = socket.select(rdset, wtset, timeout)
	else
		rd, wt = socket.select(rdset, nil, timeout)
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

local function request_file(id, req, hash, res, path)
	local promise = {
		resolve = function ()
			online[res](id, path)
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
	repo:updatehistory(hash)
	repo:changeroot(hash)
end

-- REMARK: Main thread may reading the file while writing, if file server update file.
-- It's rare because the file name is sha1 of file content. We don't need update the file.
-- Client may not request the file already exist.
function response.BLOB(hash, data)
	print("[response] BLOB", hash, #data)
	if repo:write_blob(hash, data) then
		request_complete(hash, true)
	end
end

function response.FILE(hash, size)
	print("[response] FILE", hash, size)
	repo:write_file(hash, size)
end

function response.MISSING(hash)
	print("[response] MISSING", hash)
	request_complete(hash, false)
end

function response.SLICE(hash, offset, data)
	print("[response] SLICE", hash, offset, #data)
	if repo:write_slice(hash, offset, data) then
		request_complete(hash, true)
	end
end

function response.RESOURCE(fullpath, hash)
	print("[response] RESOURCE", fullpath, hash)
	repo:set_resource(fullpath, hash)
	request_complete(fullpath, true)
end

function response.FETCH(path, hashs)
	print("[response] FETCH", path, hashs)
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
	connection_send("ROOT")
	while true do
		local ok, err = connection_dispose(INTERVAL)
		if not ok then
			if ok == nil then
				print("[ERROR] dispose", err)
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

local ListNeedGet <const> = 3
local ListNeedResource <const> = 4

function online.LIST(id, path)
	print("[online] LIST", path)
	local dir, r, hash = repo:list(path)
	if dir then
		response_id(id, dir)
		return
	end
	if r == ListNeedGet then
		request_file(id, "GET", hash, "LIST", path)
		return
	end
	if r == ListNeedResource then
		request_file(id, "RESOURCE", hash, "LIST", path)
		return
	end
	print("[ERROR] Need Change Root", path)
	response_id(id, nil)
end

function online.FETCH(id, path)
	print("[online] FETCH", path)
	request_start("FETCH", path, {
		resolve = function ()
			response_id(id)
		end,
		reject = function (_, err)
			response_err(id, err)
		end
	})
end

function online.TYPE(id, fullpath)
	print("[online] TYPE", fullpath)
	local path, name = fullpath:match "(.*)/(.-)$"
	if path == nil then
		if fullpath == "" then
			response_id(id, "dir")
			return
		end
		path = ""
		name = fullpath
	end
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

function online.GET(id, fullpath)
	print("[online] GET", fullpath)
	local path, name = fullpath:match "(.*)/(.-)$"
	if path == nil then
		path = ""
		name = fullpath
	end
	local dir, r, hash = repo:list(path)
	if not dir then
		if r == ListNeedGet then
			request_file(id, "GET", hash, "GET", fullpath)
			return
		end
		if r == ListNeedResource then
			request_file(id, "RESOURCE", hash, "GET", fullpath)
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
	local realpath = repo:hashpath(v.hash)
	local f = io.open(realpath,"rb")
	if not f then
		request_file(id, "GET", v.hash, "GET", fullpath)
	else
		f:close()
		response_id(id, realpath)
	end
end

function online.RESOURCE_SETTING(id, ext, setting)
	print("[online] RESOURCE_SETTING", ext, setting)
	connection_send("RESOURCE_SETTING", ext, setting)
	response_id(id)
end

function online.SEND(_, ...)
	connection_send(...)
end

function online.EXIT(id)
	print("[online] EXIT")
	response_id(id, nil)
	error "EXIT"
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

local function online_dispatch(ok, id, cmd, ...)
	if not ok then
		-- no req
		return false
	end
	local f = online[cmd]
	if not f then
		print("[ERROR] Unsupported online command : ", cmd)
	else
		f(id, ...)
		--local ok, err = xpcall(f, debug.traceback, ...)
		--if not ok then
		--	print(err)
		--end
	end
	return true
end

local ltask
local lt_update
local lt_switch_offline

local S = {}; do
	local session = 0
	local queue = {}
	local function lt_request(...)
		session = session + 1
		queue[#queue+1] = {session,...}
		return ltask.wait(session)
	end
	local function lt_response(id, ...)
		ltask.wakeup(id, ...)
	end

	local lt_dispatch = online_dispatch
	function lt_update()
		if #queue > 0 then
			local q = queue
			queue = {}
			for _, m in ipairs(q) do
				lt_dispatch(true, table.unpack(m))
			end
		end
	end
	function lt_switch_offline()
		lt_dispatch = offline_dispatch
	end

	function response_id(id, ...)
		if id then
			assert(type(id) ~= "string")
			if type(id) == "userdata" then
				thread.rpc_return(id, ...)
			else
				lt_response(id, ...)
			end
		end
	end

	for v in pairs(online) do
		S[v] = function (...)
			return lt_request(v, ...)
		end
	end
	for v in pairs(online) do
		S["S_"..v] = function (id, ...)
			lt_dispatch(true, id, v, ...)
		end
	end
end

local function ltask_ready()
	return coroutine.yield() == nil
end

local function ltask_update()
	if ltask == nil then
		assert(loadfile "/engine/task/service/service.lua")(true)
		ltask = require "ltask"
		ltask.dispatch(S)
	end
	lt_update()
	local SCHEDULE_IDLE <const> = 1
	local SCHEDULE_QUIT <const> = 2
	local SCHEDULE_SUCCESS <const> = 3
	while true do
		local s = ltask.schedule_message()
		if s == SCHEDULE_QUIT then
			ltask.log "${quit}"
			return
		end
		if s == SCHEDULE_IDLE then
			ltask.dispatch_wakeup()
			break
		end
		coroutine.yield()
	end
end

local function work_offline()
	lt_switch_offline()

	local c = io_req
	while true do
		offline_dispatch(c:pop())
		logger_dispatch(offline)
		if ltask_ready() then
			ltask_update()
		end
		thread.sleep(0.01)
	end
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
	while true do
		if host.update(status) then
			break
		end
		local ok, err = connection_dispose(0)
		if ok then
			while protocol.readmessage(reading, result) do
				dispatch_net(table.unpack(result))
			end
		elseif ok == nil then
			print("[ERROR] Connection Error", err)
			break
		else
			thread.sleep(0.01)
		end
	end
end

if not host then
	init_channels()
	host = {}
	function host.update(_)
		while online_dispatch(io_req:pop()) do end
		logger_dispatch(online)
		if ltask_ready() then
			ltask_update()
		end
	end
	function host.exit()
		print("Working offline")
		work_offline()
	end
end

local function main()
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

local loadfile = ...

local INTERVAL = 0.01 -- socket select timeout

-- C libs only
local thread = require "thread"
local lsocket = require "lsocket"
local protocol = require "protocol"

local config = {}
local channel = {}
local repo = {
	repo = nil,
	uncomplete = {},
}

local connection = {
	request_path = {},	-- requesting path
	request_hash = {},	-- requesting hash
	sendq = {},
	recvq = {},
	fd = nil,
	subscibe = {},
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

	local channel_user = {}
	channel.user = setmetatable({} , channel_user)

	function channel_user:__index(name)
		local c = assert(thread.channel(name))
		self[name] = c
		return c
	end

	local err = thread.channel "errlog"
	function _G.print(...)
		local t = table.pack( "[IO]", ... )
		for i= 1, t.n do
			t[i] = tostring(t[i])
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
	config.vfspath = assert(c.vfspath)
end

local function init_repo()
	local vfs = assert(loadfile(config.vfspath, 'firmware/vfs.lua'))()
	repo.repo = vfs.new(config.repopath)
end

local function connect_server()
	print("Connecting", config.address, config.port)
	local fd, err = lsocket.connect(config.address, config.port)
	if not fd then
		print(err)
		return
	end
	local fdset = { fd }
	local rd,wt = lsocket.select(nil, fdset)
	if not rd then
		print(wt)	-- select error
		fd:close()
		return
	end
	local ok, err = fd:status()
	if not ok then
		fd:close()
		print(err)
		return
	end
	print("Connected")
	return fd
end

local offline = {}

function offline:GET(path)
	local realpath, hash = repo.repo:realpath(path)
	self:push(realpath, hash)
end

function offline:LIST(path)
	local dir = repo.repo:list(path)
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

function offline:EXIT()
	self:push(nil)
	error "EXIT"
end

local function offline_dispatch(cmd, id, ...)
	local f = offline[cmd]
	if not f then
		print("Unsupported offline command : ", cmd, id)
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

local online = {}

local function connection_send(...)
	local pack = protocol.packmessage({...})
	table.insert(connection.sendq, 1, pack)
end

-- fd set for select
local rdset = {}
local wtset = {}
local function connection_dispose()
	local sending = connection.sendq
	local fd = connection.fd
	local rd, wt
	if #sending > 0  then
		rd, wt = lsocket.select(rdset, wtset, INTERVAL)
	else
		rd, wt = lsocket.select(rdset, INTERVAL)
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
			if data then
				-- socket error
				return nil, err
			end
			return nil, "Closed by remote"
		end
		table.insert(connection.recvq, data)
	end
	return true
end

-- response io request with id
local function response_id(id, ...)
	if id then
		channel.resp[id]:push(...)
	end
end

local function request_file(id, hash, path, req)
	local hash_list = connection.request_hash[hash]
	if hash_list then
		table.insert(hash_list, path)
	else
		connection.request_hash[hash] = { path }
		connection_send("GET", hash)
	end
	local path_req = connection.request_path[path]
	if not path_req then
		path_req = {}
		connection.request_path[path] = path_req
	end
	-- one request per id
	if id and path_req[id] then
		print("More than one request from id", id)
	end

	path_req[id] = req
end

local function prefetch_file(hash, path)
	local path_req = connection.request_path[path]
	if path_req then
		return
	end
	request_file(false, hash, path, "GET")
end

-- file server update hash file
local function hash_complete(hash, exist)
	local hash_list = connection.request_hash[hash]
	if not hash_list then
		return
	end
	connection.request_hash[hash] = nil
	for _, path in ipairs(hash_list) do
		local path_req = connection.request_path[path]
		if not path_req then
			print("No request:", path)
			return
		end
		connection.request_path[path] = nil
		if exist then
			for id, req in pairs(path_req) do
				online[req](id, path)	-- request/response path
			end
		else
			for id in pairs(path_req) do
				response_id(id, nil)	-- response file missing
			end
		end
	end
end

-- response functions from file server (connection)
local response = {}

function response.ROOT(hash)
	print("CHANGEROOT", hash)
	repo.repo:changeroot(hash)
end

-- REMARK: Main thread may reading the file while writing, if file server update file.
-- It's rare because the file name is sha1 of file content. We don't need update the file.
-- Client may not request the file already exist.
function response.BLOB(hash, data)
	local hashpath = repo.repo:hashpath(hash)
	local temp = hashpath .. ".download"
	local f = io.open(temp, "wb")
	if not f then
		print("Can't write to", temp)
		return
	end
	f:write(data)
	f:close()
	if not os.rename(temp, hashpath) then
		os.remove(hashpath)
		if not os.rename(temp, hashpath) then
			print("Can't rename", hashpath)
			return
		end
	end
	hash_complete(hash, true)
end

function response.FILE(hash, size)
	repo.uncomplete[hash] = { size = tonumber(size), offset = 0 }
end

function response.MISSING(hash)
	print("MISSING", hash)
	hash_complete(hash, false)
end

function response.SLICE(hash, offset, data)
	offset = tonumber(offset)
	local hashpath = repo.repo:hashpath(hash)
	local tempname = hashpath .. ".download"
	local f = io.open(tempname, "ab")
	if not f then
		print("Can't write to", tempname)
		return
	end
	local pos = f:seek "end"
	if pos ~= offset then
		f:close()
		f = io.open(tempname, "r+b")
		if not f then
			print("Can't modify", tempname)
			return
		end
		f:seek("set", offset)
	end
	f:write(data)
	f:close()
	local filedesc = repo.uncomplete[hash]
	if filedesc then
		local last_offset = filedesc.offset
		if offset ~= last_offset then
			print("Invalid offset", hash, offset, last_offset)
		end
		filedesc.offset = last_offset + #data
		if filedesc.offset == filedesc.size then
			-- complete
			repo.uncomplete[hash] = nil
			if not os.rename(tempname, hashpath) then
				-- may exist
				os.remove(hashpath)
				if not os.rename(tempname, hashpath) then
					print("Can't rename", hashpath)
				end
			end
			hash_complete(hash, true)
		end
	else
		print("Offset without header", hash, offset)
	end
end

local function waiting_for_root()
	local resp = {}
	local reading = connection.recvq
	connection_send "ROOT"
	while true do
		local ok, err = connection_dispose()
		if not ok then
			if ok == nil then
				print(err)
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

function online.GET(id, path)
	local realpath, hash = repo.repo:realpath(path)
	if not realpath then
		if hash then
			-- hash is missing, send request
			request_file(id, hash, path, "GET")
		else
			-- root changes, missing hash
			print("Need Change Root", path)
			response_id(id, nil)
		end
	else
		local f = io.open(realpath,"rb")
		if not f then
			request_file(id, hash, path, "GET")
		else
			f:close()
			response_id(id, realpath, hash)
		end
	end
end

function online.LIST(id, path)
	local dir, hash = repo.repo:list(path)
	if dir then
		local result = {}
		for k,v in pairs(dir) do
			result[k] = v.dir
		end
		response_id(id, result)
	elseif hash then
		request_file(id, hash, path, "LIST")
	else
		print("Need Change Root", path)
		response_id(id, nil)
	end
end

local function fetch_all(path)
	local dir, hash = repo.repo:list(path)
	if dir then
		for name,v in pairs(dir) do
			local subpath = path .. "/" .. name
			if v.dir then
				fetch_all(subpath)
			else
				print("Fetch", subpath)
				prefetch_file(v.hash, subpath)
			end
		end
	elseif hash then
		request_file(false, hash, path, "FETCHALL")
	else
		print("Need Change Root", path)
	end
end

function online.FETCHALL(path)
	fetch_all(path)
end

function online.TYPE(id, fullpath)
	local path, name = fullpath:match "(.*)/(.-)$"
	if path == nil then
		if fullpath == "" then
			response_id(id, "dir")
			return
		end
		path = ""
		name = fullpath
	end
	local dir, hash = repo.repo:list(path)
	if dir then
		local v = dir[name]
		if not v then
			response_id(id, nil)
		else
			response_id(id, v.dir and "dir" or "file")
		end
		return
	elseif hash then
		request_file(id, hash, fullpath, "TYPE")
	else
		response_id(id, nil)
	end
end

function online.PREFETCH(path)
	local realpath, hash = repo.repo:realpath(path)
	if realpath then
		return
	end
	if hash then
		prefetch_file(hash, path)
	end
end

function online.SUBSCIBE(channel_name, message)
	if connection.subscibe[message] then
		print("Duplicate subscibe", message, channel_name)
	end
	connection.subscibe[message] = channel_name
end

function online.SEND(...)
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
			channel.user[channel_name]:push(cmd, ...)
		else
			print("Unsupport net command", cmd)
		end
		return
	end
	f(...)
end

local function online_dispatch(ok, cmd, ...)
	if not ok then
		-- no req
		return false
	end
	local f = online[cmd]
	if not f then
		print("Unsupported online command : ", cmd)
	else
		f(...)
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
	local c = channel.req
	local result = {}
	local reading = connection.recvq
	while true do
		while online_dispatch(c:pop()) do end
		local ok, err = connection_dispose()
		while protocol.readmessage(reading, result) do
			dispatch_net(table.unpack(result))
		end

		if ok == nil then
			print("Connection Error", err)
			break
		end
	end
end

local function main()
	init_channels()
	init_config()
	init_repo()
	if config.address then
		connection.fd = connect_server()
		if connection.fd then
			work_online()
			-- socket error or closed
		end
	end
	local uncomplete = {}
	for hash in pairs(connection.request_hash) do
		table.insert(uncomplete, hash)
	end
	for _, hash in ipairs(uncomplete) do
		hash_complete(hash, false)
	end

	print("Working offline")
	work_offline()
end

main()

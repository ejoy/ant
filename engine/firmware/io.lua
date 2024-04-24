do
	local path = os.getenv "LUA_DEBUG_PATH"
	if path then
		local function load_dbg()
			if path:match "debugger%.lua$" then
				local f = assert(io.open(path))
				local str = f:read "a"
				f:close()
				return assert(load(str, "=(debugger.lua)"))(path)
			end
			return assert(loadfile "/engine/firmware/init_debug.lua", "=(debugger.lua)")()
		end
		load_dbg()
			: attach {}
			: event("setThreadName", "Thread: IO")
			: event "wait"
	end
end

local socket = require "bee.socket"
local platform = require "bee.platform"
local serialization = require "bee.serialization"
local protocol = require "protocol"
local ltask = require "ltask"
local fs = require "bee.filesystem"

local bee_select = require "bee.select"
local selector = bee_select.create()
local SELECT_READ <const> = bee_select.SELECT_READ
local SELECT_WRITE <const> = bee_select.SELECT_WRITE

local config = ...

local vfs_directory = config.directory.external .. "vfs/"
do
	fs.create_directories(config.directory.external)
	fs.current_path(config.directory.external)
	if config.vfs.needcleanup then
		fs.remove_all(vfs_directory)
	end
	fs.create_directories(vfs_directory)
end

local LOG; do
	local LOGRAW = (function ()
		if platform.os == 'windows' then
			local windows = require "bee.windows"
			if windows.isatty(io.stdout) then
				return function (data)
					windows.write_console(io.stdout, data)
					windows.write_console(io.stdout, "\n")
				end
			end
			return function (data)
				io.write(data)
				io.write("\n")
			end
		end
		local dbg = require "bee.debugging"
		if dbg.is_debugger_present() then
			if platform.os == "android" then
				local android = require "android"
				return function (data)
					android.rawlog("info", "", data)
				end
			end
			return function (data)
				io.write(data)
				io.write("\n")
			end
		end
		local logfile = config.directory.external .. "io_thread.log"
		if fs.exists(logfile) then
			fs.rename(logfile, config.directory.external .. "io_thread_1.log")
		end
		return function (data)
			local f <close> = io.open(logfile, "a+")
			if f then
				f:write(data)
				f:write("\n")
			end
		end
	end)()

	local origin = os.time() - os.clock()
	local function os_date(fmt)
		local ti, tf = math.modf(origin + os.clock())
		return os.date(fmt, ti):gsub('{ms}', ('%02d'):format(math.floor(tf*100)))
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
		local text = ('[%s][IO   ](%s:%d) %s'):format(os_date('%Y-%m-%d %H:%M:%S:{ms}'), info.short_src, info.currentline, packstring(...))
		LOGRAW(text)
	end
	print = LOG
end

local vfs = assert(loadfile "/engine/firmware/vfs.lua")()

local repo = vfs.new {
	bundlepath = config.directory.internal,
	localpath = vfs_directory,
	slot = config.vfs.slot or "",
}

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

local function request_send(...)
	if connection.fd == nil then
		return
	end
	connection_send(...)
end

local function request_resolve(arg)
	local req = connection.request[arg]
	if not req then
		return
	end
	connection.request[req] = nil
	ltask.multi_wakeup(arg, true)
end

local function request_reject(arg, err)
	local req = connection.request[arg]
	if not req then
		return
	end
	connection.request[arg] = nil
	LOG("[ERROR] " .. err)
	ltask.multi_wakeup(arg)
end

local function request_start(cmd, arg)
	if connection.fd == nil then
		LOG("[ERROR] `" .. cmd .. " ".. arg .. "` failed in offline mode.")
		return
	end
	local req = connection.request[arg]
	if req then
		assert(req == cmd)
	else
		connection.request[arg] = cmd
		connection_send(cmd, arg)
	end
	return ltask.multi_wait(arg)
end

local ListNeedGet <const> = 3
local ListNeedResource <const> = 4

local function getdir(fullpath)
	if repo.root == nil then
		ltask.multi_wait "ROOT"
	end
	while true do
		local dir, r, hash = repo:list(fullpath)
		if dir then
			return dir
		end
		if r == ListNeedGet then
			if not request_start("GET", hash) then
				return
			end
		elseif r == ListNeedResource then
			if not request_start("RESOURCE", hash) then
				return
			end
		else
			return
		end
	end
end

local S = {}

function S.LIST(fullpath)
	local dir = getdir(fullpath)
	if not dir then
		return {}
	end
	local list = {}
	for k, v in pairs(dir) do
		list[k] = v.type
	end
	return list
end

function S.TYPE(fullpath)
	if fullpath == "/" then
		return "d"
	end
	local path, name = fullpath:match "^(.*/)([^/]*)$"
	local dir = getdir(path)
	if not dir then
		return
	end
	local v = dir[name]
	if not v then
		return
	elseif v.type == "f" then
		return "f"
	else
		return "d"
	end
end

function S.READ(fullpath)
	local path, name = fullpath:match "^(.*/)([^/]*)$"
	local dir = getdir(path)
	if not dir then
		LOG("[ERROR]", "Not exist path: " .. path .. " (" .. fullpath .. ")")
		return
	end
	local v = dir[name]
	if not v then
		LOG("[ERROR]", "Not exist file: " .. fullpath)
		return
	end
	if v.type ~= 'f' then
		LOG("[ERROR]", "Not a file: " .. fullpath)
		return
	end
	while true do
		local data = repo:open(v.hash)
		if data then
			return data, fullpath
		else
			if not request_start("GET", v.hash) then
				return
			end
		end
	end
end

function S.DIRECTORY(what)
	return config.directory[what]
end

function S.RESOURCE_SETTING(setting)
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

function S.PATCH(code, data)
	local f = assert(load(code))
	f(data)
end

local NETWORK = {}

function S.REDIRECT(resp_command, service_id)
	NETWORK[resp_command] = function(...)
		ltask.send(service_id, resp_command, ...)
	end
end

function NETWORK.ROOT(hash)
	if hash == '' then
		LOG("[ERROR] INVALID ROOT")
		os.exit(-1, true)
		return
	end
	LOG("[response] ROOT", hash)
	local resources = repo:init(hash)
	for path in pairs(resources) do
		ltask.fork(getdir, path)
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

local function dispatch_net(cmd, ...)
	local f = NETWORK[cmd]
	if not f then
		LOG("[ERROR] Unsupport net command", cmd)
		return
	end
	f(...)
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

local function connect_server(address, port)
	LOG("Connecting", address, port)
	local fd, err = socket.create "tcp"
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
		local sel <close> = bee_select.create()
		sel:event_add(fd, SELECT_WRITE)
		sel:wait()
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
	local fd, err = socket.create "tcp"
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
	local sel <close> = bee_select.create()
	sel:event_add(fd, SELECT_READ)
	local quit
	while not quit do
		quit = true
		for _ in sel:wait(2000) do
			local newfd, err = fd:accept()
			if newfd == nil then
				fd:close()
				LOG("[ERROR] accept: "..err)
				return
			elseif newfd == false then
				quit = false
			else
				LOG("Accepted")
				fd:close()
				return newfd
			end
		end
	end
	LOG("[ERROR] select: timeout")
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
				LOG("[network] read close.")
				connection.flags = connection.flags & (~SELECT_READ)
				if connection.flags == 0 then
					LOG("[network] disconnected.")
					selector:event_del(connection.fd)
					connection.fd:close()
					connection.fd = nil
					work_offline()
				end
			end
		end
		if event & SELECT_WRITE ~= 0 then
			if not write_fd(connection.fd) then
				LOG("[network] write close.")
				connection.flags = connection.flags & (~SELECT_WRITE)
				if connection.flags == 0 then
					LOG("[network] disconnected.")
					selector:event_del(connection.fd)
					connection.fd:close()
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

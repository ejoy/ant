dofile "libs/init.lua"

local reponame = assert(...,  "Need repo name")
local config = {
	address = "127.0.0.1",
	port = 2018,
}

local function LOG(...)
	print(...)
end

local vrepo = require "vfs.repo"
local fs = require "filesystem"
local lsocket = require "lsocket"
local protocol = require "protocol"

local repopath = fs.personaldir() .. "/" .. reponame
LOG ("Open repo : ", repopath)
local repo = assert(vrepo.new(repopath))
local roothash = repo:index()

LOG ("Listen :", config.address, config.port)
local listenfd = assert(lsocket.bind(config.address, config.port))
local readfds = { listenfd }
local writefds = {}
local connection = {}

local client = {} ; client.__index = client

local function new_connection(fd, addr, port)
	local obj = { _fd = fd , _read = {}, _write = {}, _peer = addr .. ":" .. port }
	LOG("Accept :", obj._peer)
	connection[fd] = setmetatable(obj, client)
	table.insert(readfds, fd)
end

local function remove_fd(tbl, fd)
	for i = 1,#tbl do
		if fd == tbl[i] then
			table.remove(tbl, i)
			return
		end
	end
end

local function response(obj, ...)
	local pack = protocol.packmessage({...})
	local sending = obj._write
	if #sending == 0 then
		table.insert(writefds, obj._fd)
	end
	table.insert(sending, 1, pack)
end

local message = {}

function message:ROOT()
	repo:rebuild()
	local roothash = repo:root()
	response(self, "ROOT", roothash)
end

function message:GET(hash)
	local filename = repo:hash(hash)
	if filename == nil then
		response(self, "MISSING", hash)
		return
	end
	local f = io.open(filename, "rb")
	if not f then
		response(self, "MISSING", hash)
		return
	end
	local sz = f:seek "end"
	f:seek("set", 0)
	if sz < 0x10000 then
		response(self, "BLOB", hash, f:read "a")
	else
		response(self, "FILE", hash, tostring(sz))
		local offset = 0
		while true do
			local data = f:read(0x8000)
			response(self, "SLICE", hash, tostring(offset), data)
			offset = offset + #data
			if offset >= sz then
				break
			end
		end
	end
	f:close()
end

local debugserver = {}
local function new_debugserver(obj)
	local server = (require "debugger.io.tcp_server")('127.0.0.1', 4278)
	server:event_in(function(data)
		response(obj, "DBG", data)
	end)
	server:event_close(function()
		response(obj, "DBG", "")
	end)
	debugserver[obj] = server
	return server
end

function message:DBG(data)
	debugserver[self]:send(data)
end

local output = {}
local function dispatch_obj(obj)
	local reading_queue = obj._read
	while true do
		local msg = protocol.readmessage(reading_queue, output)
		if msg == nil then
			break
		end
		LOG("REQ :", obj._peer, msg[1])
		local f = message[msg[1]]
		if f then
			f(obj, table.unpack(msg, 2))
		end
	end
end

local function dispatch(fd)
	-- read from fd
	local obj = connection[fd]
	local data, err = fd:recv()
	if not data then
		if data then
			-- socket error
			LOG("Error :", obj._peer, err)
		end
		LOG("Closed :", obj._peer)
		remove_fd(readfds, fd)
		remove_fd(writefds, fd)
	else
		table.insert(obj._read, data)
		dispatch_obj(obj)
	end
end

local function sendout(fd)
	local obj = connection[fd]
	local sending = obj._write

	while true do
		local data = table.remove(sending)
		if data == nil then
			break
		end
		local nbytes, err = fd:send(data)
		if nbytes then
			if nbytes < #data then
				table.insert(sending, data:sub(nbytes+1))
				return
			end
		else
			if err then
				LOG("Error : ", obj._peer, err)
			end
			table.insert(sending, data)	-- push back
			return
		end
	end

	remove_fd(writefds, fd)
end

local function mainloop()
	local rd, wt = lsocket.select(readfds, writefds, 0)
	if rd then
		for _, fd in ipairs(rd) do
			if fd == listenfd then
				local newfd, addr, port = fd:accept()
				new_connection(newfd, addr, port)
				new_debugserver(connection[newfd])
			else
				dispatch(fd)
			end
		end
		for _, fd in ipairs(wt) do
			sendout(fd)
		end
	end
	for _, server in pairs(debugserver) do
		server:update()
	end
end

while true do
	mainloop()
end
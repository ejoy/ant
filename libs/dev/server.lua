local require = import and import(...) or require
local log = log and log(...) or print

local lsocket = require "lsocket"
local pack = require "pack"

local dispatch = {}

-- register command
for _, svr in ipairs { "pingserver", "fileserver" } do
	local s = require(svr)
	for cmd, func in pairs(s) do
		assert(dispatch[cmd] == nil)
		dispatch[cmd] = func
	end
end

local server = {}; server.__index = server

function server.new(config)
	local fd = assert(lsocket.bind("tcp", config.address, config.port))
	return setmetatable({ host = fd, fds = { fd }, clients = {}, request = {}, resp = {} }, server)
end

function server:new_client(fd, ip, port)
	log("%s:%s connected", ip, port)
	table.insert(self.fds, fd)
	self.clients[fd] = { ip = ip, port = port, reading = "" }
end

function server:client_request(fd)
	local obj = self.clients[fd]
	local str = fd:recv()
	if not str then
		self:kick_client(fd)
		return
	end
	local reading = obj.reading .. str
	local off = 1
	local len = #reading
	while off < len do
		local ok, pack, idx = pcall(string.unpack,"<s2", reading, off)
		if ok then
			self:queue_request(fd, pack)
			off = idx
		else
			break
		end
	end
	obj.reading = reading:sub(off)
end

function server:queue_request(fd, str)
	local req = pack.unpack(str, { fd = fd })
	if not req then
		-- invalid package
		self:kick_client(fd)
	else
		log("recv req %d", #req)
		for k,v in ipairs(req) do
			log("recv req %d %s", k,v)
		end
		table.insert(self.request, req)
	end
end

function server:kick_client(client)
	for k, fd in ipairs(self.fds) do
		if fd == client then
			table.remove(self.fds, k)
			client:close()
			local obj = self.clients[client]
			log("kick %s:%s", obj.ip, obj.port)
			self.clients[client] = nil
			self.resp[client] = nil
			break
		end
	end
end

local function response(self, req)
	local cmd = req[1]
	local func = dispatch[cmd]
	if not func then
		local obj = self.clients[req.fd]
		log("Unknown command from %s:%s", obj.ip, obj.port)
		self:kick_client(req.fd)
	else
		local resp = { func(req) }
		local queue = self.resp[req.fd]
		if not queue then
			queue = {}
			self.resp[req.fd] = queue
		end
		for _, r in ipairs(resp) do
			table.insert(queue, pack.pack(r))
		end
	end
end

function server:mainloop(timeout)
	local rd, err = lsocket.select(self.fds, timeout)
	if rd then
		for _, fd in ipairs(rd) do
			if fd == self.host then
				local newfd, ip, port = fd:accept()
				self:new_client(newfd, ip, port)
			else
				self:client_request(fd)
			end
		end
		for k,req in ipairs(self.request) do
			self.request[k] = nil
			response(self, req)
		end
	end
	for fd, queue in pairs(self.resp) do
		pack.send(fd, queue)
	end
end

return server

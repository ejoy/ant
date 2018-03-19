local require = import and import(...) or require
local log = log and log(...) or print

local lsocket = require "lsocket"
local pack = require "pack"

local client = {}; client.__index = client

function client.new(address, port)
	local fd = lsocket.connect(address, port)
	return setmetatable( { fd = { fd }, sending = {}, resp = {}, reading = "" }, client)
end

function client:send(...)
	local pack = pack.pack({...})
	table.insert(self.sending, pack)
end

local function recv(fd, resp, reading)
	reading = reading .. fd:recv()
	local off = 1
	local len = #reading
	while off < len do
		local ok, str, idx = pcall(string.unpack,"<s2", reading, off)
		if ok then
			table.insert(resp, pack.unpack(str))
			off = idx
		else
			break
		end
	end
	return reading:sub(off)
end

function client:mainloop(timeout)
	local rd, wt = lsocket.select( self.fd , self.fd, timeout )
	if rd then
		local fd = wt[1]
		if fd then
			-- can send
			pack.send(fd, self.sending)
		end
		local fd = rd[1]
		if fd then
			-- can read
			self.reading = recv(fd, self.resp, self.reading)
		end
	end
end

function client:pop()
	return table.remove(self.resp, 1)
end

return client

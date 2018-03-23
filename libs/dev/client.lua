local require = import and import(...) or require
local log = log and log(...) or print

local lsocket = require "lsocket"
local pack = require "pack"

local client = {}; client.__index = client

local recieve_cmd = {}
--register clent command
do
    local c = require "clientcommand"
    for cmd, func in pairs(c) do
        --prevent duplicate cmd
        assert(recieve_cmd[cmd] == nil)
        print("client cmd:",cmd, "func:",func)
        recieve_cmd[cmd] = func

    end
end

function client.new(address, port)
	local fd = lsocket.connect(address, port)
    print("new client", fd)
	return setmetatable( { fd = { fd }, sending = {}, resp = {}, reading = "" }, client)
end

function client:send(...)
	local package = {...}

	local cmd = package[1]
	if cmd == "GET" then
		--check if we have local copy
		local file_path = package[2]
		local child_path = string.gsub(file_path, "ServerFiles", "ClientFiles")

        local file_process = require "fileprocess"
        local hash = file_process.CalculateHash(child_path)
        package[3] = hash
    elseif cmd == "EXIST" then
        local file_path = package[2]
        local file_process = require "fileprocess"
        local hash = file_process.CalculateHash(file_path)
        package[3] = hash
    end

	local pack = pack.pack(package)
	--need to calculate the sha1 value
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

function client:process_response(resp)
    local cmd = resp[1]
    local func = recieve_cmd[cmd]
    if not func then
        log("Unknown command from server %s",cmd)
        print("unknown command", cmd)
        return
    end
    --execute the function
    func(resp)
end

return client

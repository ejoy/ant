dofile "libs/init.lua"

local config = {
	address = "127.0.0.1",
	port = 2018,
}

local function LOG(...)
	print(...)
end

local lsocket = require "lsocket"
local protocol = require "protocol"


LOG("Connect to", config.address, config.port)
local fd = lsocket.connect(config.address, config.port)
lsocket.select(nil, {fd})
LOG("Connected")

local sending = {}
local reading = {}

local function send_req(...)
	local pack = protocol.packmessage({...})
	print("REQ", ...)
	table.insert(sending, 1, pack)
end

-------- req dir list

local dir_cache = {}
local hash_cache = {}

local function list_dir(hash, ident)
	local dir = dir_cache[hash]
	if not dir or dir.request then
		if hash_cache[hash] ~= "request" then
			-- request again
			dir_cache[hash] = { request = true }
			send_req("GET", hash)
		end
		coroutine.yield(hash)
		dir = assert(dir_cache[hash])
	end
	for _, item in ipairs(dir) do
		local status = hash_cache[item.hash]
		print(string.format("%s%s%s %s (%s)", (" "):rep(ident), item.name, item.type == 'd' and "/" or "", item.hash, status))
		if status == nil then
			send_req("GET",item.hash)
			if item.type == 'd' then
				dir_cache[item.hash] = { request = true } -- waiting for dir
			end
			hash_cache[item.hash] = "request"
		end
		if item.type == 'd' then
			list_dir(assert(item.hash), ident+2)
		end
	end
end

--------

local message = {}
local sessions = {}
local files = {}

function message.ROOT(hash)
	assert(hash)
	local co = coroutine.create(list_dir)
	local ok, hash = coroutine.resume(co, hash, 0)
	if not ok then
		error(debug.traceback(co))
	end
	if hash then
		assert(sessions[hash] == nil)
		sessions[hash] = co
	end
end

function message.FILE(hash, size)
	size = tonumber(size)
	files[hash] = { size = size , content = "" }
end

local function solve_dir(dir, hash, data)
	print("DIR", hash)
	for line in data:gmatch "([^\n]*)" do
		print("  ", line)
		local t, hash, name = line:match "([fd]) (%S+) (%S+)"
		table.insert(dir, { type = t, hash = hash, name = name })
	end
	dir.request = nil
	local co = sessions[hash]
	if co then
		local ok, next_hash = coroutine.resume(co)
		if not ok then
			error(next_hash)
		end
		sessions[hash] = nil
		if next_hash then
			sessions[next_hash] = co
		else
			print "DONE"
		end
	end
end

function message.BLOB(hash, data)
	hash_cache[hash] = "done"
	local dir = dir_cache[hash]
	if dir then
		solve_dir(dir, hash, data)
	end
end

function message.SLICE(hash, offset, data)
	local dir = dir_cache[hash]
	if dir and dir.request then
		local c = files[hash].content
		if #c == offset then
			c = c .. data
		elseif #c > offset then
			-- ignore
			return
		else
			c = c:sub(1, offset) .. data
		end

		file.content = c

		if #c == file.size then
			hash_cache[hash] = "done"
			solve_dir(dir, hash, c)
		end
	else
		if offset + #data == files[hash].size then
			hash_cache[hash] = "done"
		end
	end
end

function message.MISSING(hash)
	hash_cache[hash] = "missing"
	local dir = dir_cache[hash]
	if dir and dir.request then
		dir.request = nil -- missing
	end
end

local result = {}
local function dispatch()
	while protocol.readmessage(reading, result) do
		local command = result[1]
		LOG("Command :", command, result[2])
		local f = message[command]
		if f then
			f(table.unpack(result, 2))
		end
	end
end

local function sendout()
	while true do
		local data = table.remove(sending)
		if data == nil then
			return
		end
		local nbytes, err = fd:send(data)
		if nbytes then
			if nbytes < #data then
				table.insert(sending, data:sub(nbytes+1))
				return
			end
		else
			if err then
				error(err)
			end
			table.insert(sending, data)	-- push back
			return
		end
	end
end

local readfds = { fd }
local writefds = { fd }
local function mainloop()
	local rd, wt
	if #sending > 0 then
		rd, wt = assert(lsocket.select(readfds, writefds))
	else
		rd = assert(lsocket.select(readfds))
	end

	if rd[1] then
		-- read
		local data, err = fd:recv()
		if not data then
			if data then
				-- socket error
				LOG("Error :", err)
			end
			LOG("Closed by remote")
			os.exit()
		end
		table.insert(reading, data)
		dispatch()
	end
	if wt and wt[1] then
		sendout()
	end
end

send_req "ROOT"
while true do
	mainloop()
end


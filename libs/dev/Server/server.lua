local require = import and import(...) or require
local log = log and log(...) or print

local pack = require "pack"
local lsocket = require "lsocket"
local command_cache = {}

local packing_cache = {}

local dispatch = {}

-- register command
for _, svr in ipairs { "pingserver", "fileserver" } do
	local s = require(svr)
	for cmd, func in pairs(s) do
        --prevent duplicate cmd
		assert(dispatch[cmd] == nil)
		print("server cmd:",cmd, "func:",func)
		dispatch[cmd] = func
	end
end

local server = {}; server.__index = server

local file_server = require "fileserver"
-------------------------------------------------------------
local function HandlePackage(response_pkg, fd)
    if not packing_cache[fd] then
        packing_cache[fd] = {}
    end

    local cmd_type = response_pkg[1]
    if cmd_type == "MULTI_PACKAGE" then
        local file_path = response_pkg[2]
        local client_path = response_pkg[3]
        local file_size = response_pkg[4]
        local hash = response_pkg[5]
        local offset = response_pkg[6]
        if not offset then
            offset = 0
        end

        --for now, hard coded a maximum package number to send per tick(which is 10)
        --TODO: dynamic adjust the number according to the total package need to send
        local file = io.open(file_path, "rb")

        --for i = 1, MAX_PACKAGE_NUM do
        while true do
            if not file then
                --TODO: do something here, maybe the file got deleted on the server
                --TODO: or the file path is somehow incorrect
                log("file path invalid: %s", file_path)
                return
            end


            local MAX_PACKAGE_SIZE = file_server.MAX_PACKAGE_SIZE
            io.input(file)
            file:seek("set", offset)

            local remain_size = file_size - offset
            local read_size = 0
            if remain_size > MAX_PACKAGE_SIZE then
                --can't fit it in one package
                read_size = MAX_PACKAGE_SIZE
            else
                --this is the last package
                read_size = remain_size
            end

            local file_data = file:read(read_size)
            local progress = (offset + read_size).."/"..file_size
            local client_package = {"FILE", client_path, hash, progress, file_data}
            print("read size", read_size, progress)
            --put it on a lanes, store the handle
            local pack_l = pack.pack(client_package)
            local nbytes = fd:send(pack_l)
            --if fd write queue is full
            if not nbytes then
                break;
            end
            print("sending", file_path, "remaining", file_size - offset)

            --table.insert(packing_cache[fd],pack_l)

            offset = offset + read_size
            if offset >= file_size then
                break
            end

        end

        response_pkg[6] = offset
        io.close(file)

        if offset >= file_size then
            return "DONE"
        else
            return "RUNNING"
        end
        --return directory
    elseif cmd_type == "FILE"  or cmd_type == "EXIST_CHECK" then
        local pack_l = pack.pack(response_pkg)
        local nbytes = fd:send(pack_l)
        if not nbytes then
            return "RUNNING"
        else
            return "DONE"
        end
    elseif cmd_type == "DIR" then
        local list_path = response_pkg[2]
        local file_num = response_pkg[3]
        local dir_table = response_pkg[4]
        local offset = response_pkg[5]
        if not offset then
            --start from the first package
            offset = 1
        end

        --for i = 1, MAX_PACKAGE_NUM do
        while true do
            local progress = tostring(offset).."/"..tostring(file_num)
            local file_name = dir_table[offset]

            --for now, send one each loop
            --TODO:add hash
            local client_package = {cmd_type, list_path, progress, file_name}

            local pack_l = pack.pack(client_package)
            local nbytes = fd:send(pack_l)
            --if fd write is full
            if not nbytes then
                break
            end
            --table.insert(packing_cache[fd], package)

            offset = offset + 1

            if offset > file_num then
                break
            end

        end

        response_pkg[5] = offset
        if offset > file_num then
            return "DONE"
        else
            return "RUNNING"
        end
    else
        print("cmd: " .. cmd_type .." not support yet")
        return "DONE"
    end
end

--update the packagehandler
--including process package command
--send package for packing
--send out packed package
function server:PackageHandleUpdate()
    local remove_list ={}
    for k,v in ipairs(command_cache) do
        local a_cmd = v[1]
        local fd = v[2]
        local status = HandlePackage(a_cmd, fd)
        if status == "DONE" then
            table.insert(remove_list, k)
        end
    end

    --remove finished command
    for i = #remove_list, 1, -1 do
        table.remove(command_cache, remove_list[i])
    end

end

--------------------------------------------------------------
function server.new(config)
	local fd = assert(lsocket.bind("tcp", config.address, config.port))
	return setmetatable({ host = fd, fds = { fd }, clients = {}, request = {}, resp = {}}, server)
end

function server:new_client(fd, ip, port)
	log("%s:%s connected", ip, port)
	table.insert(self.fds, fd)
	self.clients[fd] = { ip = ip, port = port, reading = "" }
end

function server:client_request(fd)
	local obj = self.clients[fd]
    --recv() reads data from a socket
	local str = fd:recv()
	if not str then
        --if nil,means the client is shutdown
		self:kick_client(fd)
		return
	end
	local reading = obj.reading .. str
	local off = 1
	local len = #reading
	while off < len do
        --unpack the string
        --<s2 meaning:
        --s[n]: a string preceded by its length coded as an unsigned integer with n bytes (default is a size_t)
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


--put request from client in queue
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

--store handle of lanes, check the result periodically
local function response(self, req)
	local cmd = req[1]
	local func = dispatch[cmd]

	if not func then
		local obj = self.clients[req.fd]
		log("Unknown command from %s:%s", obj.ip, obj.port)
		self:kick_client(req.fd)
	else
		local resp = { func(req) }
        --handle the resp
        --collect command
        for _, a_cmd in ipairs(resp) do

            local command_package = {a_cmd, req.fd}
            table.insert(command_cache, command_package)
        end
	end
end

local function UpdateFileHash()
    --create a file to store the filename, last modification time and hash table
    --for files, use a counter to check it periodically
    --for now, hard code the path

    local file_process = require "fileprocess"
    local file_hash = io.open(file_process.hashfile, "a+")

    local dir_path = file_process.dir_path

    if not file_hash then
        print("hash file not found")
        return
    end

    io.input(file_hash)

    local lines = {}
    for line in io.lines() do
        lines[#lines+1] = line
    end

    local time_stamp_table = file_process.time_stamp_table
    local file_hash_table = file_process.file_hash_table

    for i = 1, #lines+1, 3 do
        --store filename
        local filename = lines[i]
        if not filename then break end

        local filetime = lines[i+1]
        local filehash = lines[i+2]
--        print(filename, filetime, filehash)

        time_stamp_table[filename] = filetime
        file_hash_table[filename] = filehash
    end

    io.close(file_hash)

    --TODO: some sort of directory projection
    --TODO: put it on another thread??
    --use another thread to do for writing
    local dir_table = file_process.GetDirectoryList(dir_path)

    for _, v in pairs(dir_table) do
        --for each table, match the filename
        --if not found, then add the file info later
        local full_path = dir_path.."/"..v
        local new_time_stamp = file_process.GetLastModificationTime(full_path)

        local time_stamp = time_stamp_table[full_path]
        --time_stamp could be nil, in that case the new file will be added
        if new_time_stamp ~= time_stamp then
            time_stamp_table[full_path] = new_time_stamp
            file_hash_table[full_path] = file_process.CalculateHash(full_path)
        end
    end

    file_process:UpdateHashFile()
end

local hash_update_counter = 0
function server:mainloop(timeout)
	local rd, err = lsocket.select(self.fds, timeout)
	if rd then
        --collect the data sent from clients
		for _, fd in ipairs(rd) do
            if fd == self.host then
                --new client connected
                local newfd, ip, port = fd:accept()
                self:new_client(newfd, ip, port)
            else
                --collect requests from clients
                self:client_request(fd)
            end
		end
        --base on the valid request of the clients, response to their request
		for k,req in ipairs(self.request) do
			self.request[k] = nil
			response(self, req)
		end
	end

    self:PackageHandleUpdate()
    --check/update file hash every 10 ticks
    --[[
    if hash_update_counter % 10 == 0 then
        UpdateFileHash()
        hash_update_counter = 0
    end

    hash_update_counter = hash_update_counter + 1
    --]]
end

return server

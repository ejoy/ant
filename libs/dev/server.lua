local require = import and import(...) or require
local log = log and log(...) or print

local lsocket = require "lsocket"
local pack = require "pack"

local dispatch = {}

--used for manage sending multiple package for one file
local multipackagemgr = {}

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
        --TODO: put into a different module?
        --collect multipackage command
        for _, a_cmd in ipairs(resp) do

            local resp_cmd = a_cmd[1]
            if resp_cmd == "MULTI_PACKAGE" or resp_cmd == "DIR" then

                local multi_pac = multipackagemgr[req.fd]
                if not multi_pac then
                    multi_pac = {}
                    multipackagemgr[req.fd] = multi_pac
                end

                --put the cmd into a multipac cmd
                table.insert(multipackagemgr[req.fd], a_cmd)
            else

                local queue = self.resp[req.fd]
                --put the response for the client in queue
                if not queue then
                    queue = {}
                    self.resp[req.fd] = queue
                end
                table.insert(queue, pack.pack(a_cmd))
            end
        end


	end
end

local function HandleMultiPackage(self)
    --handle multi_pac
    for fd, multi_pac in pairs(multipackagemgr) do
        local remove_table = {}
        for idx, a_cmd in ipairs(multi_pac) do
            local cmd_type = a_cmd[1]
            if cmd_type == "MULTI_PACKAGE" then
                local file_path = a_cmd[2]
                local client_path = a_cmd[3]
                local file_size = a_cmd[4]
                local hash = a_cmd[5]
                local offset = a_cmd[6]
                if not offset then
                    offset = 0
                end

                --for now, hard coded a maximum package number to send per tick(which is 10)
                --TODO: dynamic adjust the number according to the total package need to send
                local file = io.open(file_path, "rb")
                for i = 1, 10, 1 do
                    print("sending", file_path, "remaining", file_size - offset)

                    if not file then
                        --TODO: do something here, maybe the file got deleted on the server
                        --TODO: or the file path is somehow incorrect
                        log("file path invalid: %s", file_path)
                        return
                    end

                    local file_server = require "fileserver"
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
                    local progress = offset.."/"..file_size
                    local client_package = {"FILE", client_path, hash, progress, file_data}

                    local queue = self.resp[fd]
                    --put the response for the client in queue
                    if not queue then
                        queue = {}
                        self.resp[fd] = queue
                    end

                    table.insert(queue, pack.pack(client_package))

                    offset = offset + read_size
                    a_cmd[6] = offset

                    if offset >= file_size then
                        --already finished
                        break
                    end
                end
                io.close(file)

                --is done, need to remove
                if offset >= file_size then
                    table.insert(remove_table, idx)
                    --print("delete progress", file_path)
                    break
                end

                --return directory
            elseif cmd_type == "DIR" then
                local list_path = a_cmd[2]
                local file_num = a_cmd[3]
                local dir_table = a_cmd[4]
                local offset = a_cmd[5]
                if not offset then
                    --start from the first package
                    offset = 1
                end

                for i = 1, 5, 1 do
                    local progress = tostring(offset).."/"..tostring(file_num)
                    local file_name = dir_table[offset]

                    local queue = self.resp[fd]
                    if not queue then
                        queue = {}
                        self.resp[fd] = queue
                    end

                    --for now, send one each loop
                    --TODO:add hash
                    local package = {cmd_type, list_path, progress, file_name}
                    table.insert(queue, pack.pack(package))

                    offset = offset + 1

                    if offset > file_num then
                        break
                    end
                end

                if offset > file_num then
                    table.insert(remove_table, idx)
                    break
                end
                a_cmd[5] = offset
            end

        end

        --need to delete those cmd that already done
        for i = #remove_table, 1, -1 do
            table.remove(multi_pac,i)
        end
    end

end

local function UpdateFileHash()
    --create a file to store the filename, last modification time and hash table
    --for files, use a counter to check it periodically
    --for now, hard code the path
    local file_hash = io.open("./hashtable", "a+")

    if not file_hash then
        print("no hash file")
        return
    end

    --TODO: some sort of directory projection
    local dir_path = "Serverfiles"
    local file_process = require "fileprocess"
    local dir_table = file_process.GetDirectoryList(dir_path)

    io.input(file_hash)
    local file_data = io.read("*a")

    local add_list = {}
    for _, v in pairs(dir_table) do
        --need to deal with character like ( ) . %
        local find_str = string.gsub(v, "%W", "%%W")

        --test time stamp
        --file_process.GetLastModificationTime(dir_path.."/"..v)

        --for each table, match the filename
        --if not found, then add the file info later
        local name_pos = 0
        _, name_pos = string.find(file_data, find_str)
        if not name_pos then
            table.insert(add_list, v)
        else
            --TODO:
            local time_stamp_pos = name_pos + 2
            file_hash:seek("set",time_stamp_pos)
            print(file_hash:read("*l"))
            print("found: ", v)
        end
    end


    io.output(file_hash)
    for _, filename in pairs(add_list) do
        local time_stamp = file_process.GetLastModificationTime(dir_path.."/"..filename)
        io.write(filename)
        print("add", filename)
        io.write("\n")
        io.write(time_stamp)
        io.write("\n")
    end

    io.close(file_hash)
    end

local hash_update_counter = 1
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

    HandleMultiPackage(self)
    --handle self.resp
    for fd, queue in pairs(self.resp) do
        pack.send(fd, queue)
    end

    --check/update file hash every 5 ticks
    if hash_update_counter % 5 == 0 then
        UpdateFileHash()
        hash_update_counter = 0
    end

    hash_update_counter = hash_update_counter + 1

end

return server

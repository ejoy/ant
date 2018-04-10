local require = import and import(...) or require
local log = log and log(...) or print

local lsocket = require "lsocket"
local pack = require "pack"
local crypt = require "crypt"
local fileprocess = require "fileprocess"

local client = {}; client.__index = client

local logic_request = {}
--file data stored in mem, e.g. remote required file
local mem_file = {}
local mem_file_status = {}
local current_reading = ""

local _linda = nil
local _filemanager = nil
---------------------------------------------------
local clientcommand = {}
--cmd while recieving data from server
--there are two types of file data
--one will store as file
--one will store in the memory
--the data stored in the memory will have record in mem_file_status
function clientcommand.FILE(resp)
    --resp[1] is cmd name "FILE"
    --resp[2] is the file path in client
    --resp[3] is the file hash value
    --resp[4] is the progress "current/total"
    --resp[5] is the file data
    assert(resp[1] == "FILE")

    local progress = resp[4]

    local slash = string.find(progress, "%/")
    local offset = tonumber(string.sub(progress, 1, slash - 1))
    local total_pack = tonumber(string.sub(progress, slash+1, -1))
    local file_path = resp[2]

    if not mem_file_status[file_path] then
        --store in file

        local hash = resp[3]
        --file dose not exist on server
        if not hash then
            --TODO: handle this situation
            return
        end
        --use temp name
        --local temp_path_hash = "temp-" .. file_path

        local folder = "Files/"..string.sub(hash, 1,3)

        local real_path = folder .. "/" .. hash
        print("received", resp[1],resp[2],resp[4])
        print("--", folder)
        --print("package info", resp[1], resp[2],resp[4], resp[5])
        --if is the first package, will delete the origin file
        --if is other package, will add to the existing file
        --TODO: consider if the order is not correct
        local file  = nil

        if offset <= fileprocess.MAX_CALC_CHUNK then
            _linda:send("new file", {hash, file_path})
            --TODO _filemanager is diff from file_mgr in clientwindow.lua
            --TODO study this
            _filemanager:AddFileRecord(hash, file_path)

            local filesystem = require "winfile"
            filesystem.mkdir(folder)
            --we should use a temp file, for now is "temp-" string combine with hash value
            --file = io.open(temp_path_hash, "wb")
            file = io.open(real_path, "wb")
            print("create new file", real_path)
        else
            --file = io.open(temp_path_hash, "ab")
            --print("write to file", temp_path_hash)
            file = io.open(real_path, "ab")
            print("write to file", real_path)
        end

        if file == nil then
            return
        end

        --output to client file directory
        io.output(file)
        io.write(resp[5])   --write the data into the client file
        io.close(file)

         if offset >= total_pack then
            --the final package, the file is complete, change the name to normal name
            --for now, just remove the old file
            --TODO version management/control
            --os.remove(file_path)
            --os.rename(temp_path_hash, file_path)
        end
    else
        --store in mem
        mem_file[file_path] = mem_file[file_path]..resp[5]

        if offset >= total_pack then
            mem_file_status[file_path] = "FINISHED"
            --send the data back
            if file_path == current_reading then
                _linda:send("mem_data", mem_file[file_path])
                current_reading = ""
            end
        else
            mem_file_status[file_path] = "RECEIVING"
        end
    end
end

--handle error
--for now just print the error message
function clientcommand.ERROR(resp)
    for k, v in pairs(resp) do
        print(k, v)
    end
end

function clientcommand.EXIST_CHECK(resp)
    assert(resp[1] == "EXIST_CHECK", "COMMAND: "..resp[1].." invalid, shoule be EXIST_CHECK")
    local result = resp[2]
    if result == "true" then
        print("File exists on the server")
    elseif result == "false" then
        print("File does not exist on the server")
    else
        print("EXIST CHECK result invalid: "..result)
    end
end

function clientcommand.DIR(resp)

    print(resp[1], resp[2], resp[3], resp[4])

end
---------------------------------------------------


local recieve_cmd = {}
--register client command
do
    for cmd, func in pairs(clientcommand) do
        --prevent duplicate cmd
        assert(recieve_cmd[cmd] == nil)
        --print("client cmd:",cmd, "func:",func)
        recieve_cmd[cmd] = func

    end
end

function client.new(address, port, init_linda, filemanager)
	local fd = lsocket.connect(address, port)
    _linda = init_linda
    _filemanager = filemanager
	return setmetatable( { fd = { fd }, sending = {}, resp = {}, reading = "", linda = init_linda , file_mgr = filemanager}, client)
end

function client:send(...)
	local client_req = { ...}

	local cmd = client_req[1]
	if cmd == "GET" or cmd == "EXIST" then
		--check if we have local copy
		local file_path = client_req[2]

        print("file path", file_path)
        file_path = _filemanager:GetRealPath(file_path)
        print("get real path", file_path)
        --client does have it
        if file_path then
            file_path = "Files/"..file_path
            print("real path", file_path)
            local hash = fileprocess.CalculateHash(file_path)
            client_req[3] = hash
        end
    elseif cmd == "OPEN" then
        --TODO add hash check?
        --cmd for server should be the same
        --however, the client may handle differently
        client_req[1] = "GET"
        local file_path = client_req[2]
        mem_file_status[file_path] = "pending"
        mem_file[file_path] = ""
        current_reading = file_path
    end

	--need to calculate the sha1 value
	table.insert(self.sending, pack.pack(client_req))
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

function client:CollectRequest()
    local count = 0
    while true do
        --print("probing")
        local key, value = _linda:receive(0.05, "request")
        if not value then
            break
        else
            for k,v in pairs(value) do
                print("package", k, v)
            end
            --calculate sha1 value of the request
            --if the request is already exist, ignore the latter ones
            local pack_req = pack.pack(value)
            local sha1 = crypt.hexencode(crypt.sha1(pack_req))

            --table.insert(logic_request,value)
            --count = count + 1
            ---[[
            if not logic_request[sha1] then
                logic_request[sha1] = value
                count = count + 1
            end
            --]]
            --for now, hard coded a 10 request limit per update
            if count == 10 then
                break
            end
        end
    end
end

function client:mainloop(timeout)
    self.CollectRequest()
    for _, req in pairs(logic_request) do
        local cmd = req[1]
        local file_name = req[2]

        if cmd == "OPEN" then
            local cache_status = mem_file_status[file_name]
            --if the cache does not exist, then send the request info
            --TODO: hash check??
            if not cache_status then
                self:send(table.unpack(req))
            elseif cache_status == "FINISHED" then
                _linda:send("mem_data", mem_file[file_name])
            end
            --other in status like "RUNNING", do nothing but wait

        else --if cmd == "GET" or cmd == "LIST" then
            --simply send the request, does not bother if it already had it
            --or it need to load the file
            self:send(table.unpack(req))
        end
    end


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

    for i,_ in pairs(logic_request) do
        logic_request[i] = nil
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

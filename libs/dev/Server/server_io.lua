local require = import and import(...) or require
local log = log and log(...) or print

local pack = require "pack"

local lsocket = require "lsocket"
local command_cache = {}

--give every socket a id(string), and server will only know the id not the socket itself
--if server use an id that can't be found in socket table, it should be device's udid
local socket_table = {}
local socket_count = 0

local connected_devices = {}

local dispatch = {}

local libimobiledevicelua = require "libimobiledevicelua"
local project_directory = ""

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

local function SendData(fd, pack_l)
    --print("send data",string.format("%q", pack_l))
    if not socket_table[fd] then
        if fd == "all" then
            local byte_sent = 0
            for k, v in pairs(connected_devices) do
                if v == true then
                    byte_sent = byte_sent + libimobiledevicelua.Send(k, pack_l)
                end
            end

            return byte_sent
        else
            return libimobiledevicelua.Send(fd, pack_l)
        end

    else
        return fd:send(pack_l)
    end
end

local file_server = require "fileserver"
-------------------------------------------------------------
local function HandlePackage(response_pkg, id, self)
    --fd may be a socket, also can be a string represent the udid, treat them differently
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

            local nbytes = SendData(id, pack_l)

            --local nbytes = fd:send(pack_l)
            --if fd write queue is full
            if not nbytes then
                break;
            end
            print("sending", file_path, "remaining", file_size - offset)

            offset = offset + nbytes    --should be the data size that actually sent
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
    elseif cmd_type == "FILE"  or
            cmd_type == "EXIST_CHECK" or
            cmd_type == "RUN" or
            cmd_type == "ERROR" or
            cmd_type == "SCREENSHOT" then

        local pack_l = pack.pack(response_pkg)
        --local nbytes = fd:send(pack_l)
        local nbytes = SendData(id, pack_l)
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
            --local nbytes = fd:send(pack_l)
            local nbytes = SendData(id, pack_l)
            --if fd write is full
            if not nbytes then
                break
            end

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
    elseif cmd_type == "LOG" then
        --do nothing for now
        --response_pkg[2] is category info
        --response_pkg[3] is log data
        table.insert(self.log, {table.unpack(response_pkg, 2)})
        return "DONE"
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
        local id = v[2]
        local status = HandlePackage(a_cmd, id, self)
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
function server.new(config, linda)
    local fd = assert(lsocket.connect(config.address, config.port))
    local fd_name = config.address .. ":" .. config.port
    --print("fd", fd_name)
    socket_table[fd_name] = fd
    local new_client = {ip = config.address, port = config.port, reading = ""}
    local var_table = {ids = {fd_name}, clients = {[fd_name] = new_client}, request = {} ,resp = {}, log = {}, linda = linda, address = config.address, port = config.port}
    return setmetatable(var_table, server)
end

function server:new_client(id, ip, port)
    table.insert(self.ids, id)
    self.clients[id] = {ip = ip, port = port, reading = ""}
end


local function GetIdData(id)
    if socket_table[id] then
        return socket_table[id]:recv()
    else
        return libimobiledevicelua.Recv(id)
    end
end

function server:client_request(id)
    local str = GetIdData(id)

    if not str then
        local fd = socket_table[id]
        if not fd then
            --if nil,means the client is shutdown
            self:kick_client(id)
        end

        return
    end

    print("data", str)
    local obj = self.clients[id]
    local reading = obj.reading .. str
    local off = 1
    local len = #reading
    while off < len do
        --unpack the string
        --<s2 meaning:
        --s[n]: a string preceded by its length coded as an unsigned integer with n bytes (default is a size_t)
        local ok, pack, idx = pcall(string.unpack,"<s2", reading, off)
        if ok then
            self:queue_request(id, pack)
            off = idx
        else
            break
        end
    end
    obj.reading = reading:sub(off)
end

--put request from client in queue
function server:queue_request(id, str)
    local req = pack.unpack(str, {id = id})
    if not req then
        self:kick_client(id)
    else
        table.insert(self.request, req)
    end
end

function server:kick_client(client_id)
    print("kick id", client_id)
    for k, id in ipairs(self.ids) do
        if id == client_id then
            table.remove(self.ids, k)
            local fd = socket_table[client_id]
            if fd then
                fd:close()
            else
                connected_devices[client_id] = nil
            end
            self.clients[client_id] = nil
         --   self.request[client_id] = nil
            self.resp[client_id] = nil

            return
        end
    end
end

local function save_ppm(filename, data, width, height, pitch)
    local f = assert(io.open(filename, "wb"))
    f:write(string.format("P3\n%d %d\n255\n",width, height))
    local line = 0
    for i = 0, height-1 do
        for j = 0, width-1 do
            local r,g,b,a = string.unpack("BBBB",data,i*pitch+j*4+1)
            f:write(r," ",g," ",b," ")
            line = line + 1
            if line > 8 then
                f:write "\n"
                line = 0
            end
        end
    end
    f:close()
end

local screenshot_cache = nil
local max_screenshot_pack = 64*1024 - 100
--store handle of lanes, check the result periodically
local function response(self, req)
    print("cmd and second is ", req[1], req[2])
    local cmd = req[1]
    --if is require command, need project_directory
    if cmd == "REQUIRE" or cmd == "GET" or cmd == "EXIST" then
        --table.insert(req, project_directory)
        req.project_dir = project_directory
    end

    local func = dispatch[cmd]

    if not func then
        self:kick_client(req.id)
    else
        local resp = { func(req) }
        --handle the resp
        --collect command
        if resp then
            for _, a_cmd in ipairs(resp) do
                if a_cmd[1] == "SCREENSHOT" then

                     ---[[
                    local name = a_cmd[2]
                    local size = a_cmd[3]
                    local offset = a_cmd[4]
                    local data = a_cmd[5]

                    if tonumber(offset) <= max_screenshot_pack + 1 then
                        screenshot_cache = nil
                        screenshot_cache = {name, data}

                    else
                    --    print("length before", #screenshot_cache[2], offset, #data)
                        screenshot_cache[2] = screenshot_cache[2]..data
                    --    print("length after", #screenshot_cache[2], offset)
                    end

                    if offset >= size then
                        --send data to ui screen
                        self.linda:send("response", {"SCREENSHOT", screenshot_cache})
                    end
                    --]]
                else
                    local command_package = {a_cmd, req.id}
                    table.insert(command_cache, command_package)
                end
            end
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


function server:CheckNewDevice()
    --check devices every update
    --TODO: find a way to trigger c function call back

    for k, _ in pairs(connected_devices) do
        connected_devices[k] = false
    end

    local current_devices = libimobiledevicelua.GetDevices()

    for k, udid in pairs(current_devices) do
        --new device
        if connected_devices[udid] == nil then
            local result = libimobiledevicelua.Connect(udid, self.port)
            if  result then
                --   print("failed to create connection with", udid)
                print("connect to ".. udid .." successful")
                self:new_client(udid, nil, self.port)

                connected_devices[udid] = true --means device "v" is connected now

                table.insert(self.log, "connect to "..udid)
            end
        else
            connected_devices[udid] = true
        end

    end

    --if device no longer connected, kick the device
    for k, v in pairs(connected_devices) do
        if v == false then
            self:kick_client(k)
        end
    end
end

local hash_update_counter = 0
function server:mainloop(timeout)

    self:GetLindaMsg()
    --self:CheckNewDevice()
    --TODO: currently no use of lsocket connection, implement later (for wifi connection)

    for _, id in ipairs(self.ids) do
        self:client_request(id)
    end

    for k,req in ipairs(self.request) do
        self.request[k] = nil
        response(self, req)
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
    self:SendLog()
end

function server:SendLog()
    for _, v in ipairs(self.log) do
        self.linda:send("log", v)
    end

    self.log = {}
end

function server:GetLindaMsg()
    while true do
        local key, value = self.linda:receive(0.05, "command")
        if value then
            self:HandleIupWindowRequest(value.udid, value.cmd, value.cmd_data)
        else
            break
        end
    end

    while true do
        local key, value = self.linda:receive(0.05, "proj dir")
        if value then
            project_directory = value
            print("change project directory to", project_directory)
        else
            break
        end
    end
end

function server:HandleIupWindowRequest(udid, cmd, cmd_data)
    --handle request create from iup window
    --if udid is "all", means is for all devices
    if cmd == "TRANSIT_DIR" then
        local full_path_table = cmd_data
        if not full_path_table or type(full_path_table) ~= "table" then
            print("no path table found")
            return
        end

        for _, v in ipairs(full_path_table) do
            --is equal to client sends "GET" command to server
            local request = {{"GET", v}, id = udid}
            table.insert(self.request, request)
        end
    elseif cmd == "RUN" then
        local entrance_path = cmd_data[1]
        local request = {{"RUN", entrance_path}, udid}

        print("RUN cmd sent", udid, entrance_path)
        table.insert(command_cache, request)
    elseif cmd == "CONNECT" then
        --connect to device
        local result = libimobiledevicelua.Connect(udid, self.port)
        if  result then
            --   print("failed to create connection with", udid)
            print("connect to ".. udid .." successful")
            self:new_client(udid, nil, self.port)
            table.insert(self.log, "connect to "..udid)
            self.linda:send("response", {"CONNECT", udid})
            connected_devices[udid] = true
        end

    elseif cmd == "DISCONNECT" then
        --disconnect device
        local result = libimobiledevicelua.Disconnect(udid)
        if result then
            self:kick_client(udid)
            self.linda:send("response", {"DISCONNECT", udid})
        end
    elseif cmd == "SCREENSHOT" then
        --todo unique id 1, for now just use 1
        local request = {{"SCREENSHOT", 1}, udid}
        print("send SCREENSHOT cmd")
        table.insert(command_cache, request)
    else
        print("Iup Window Request not support yet")
    end
end

return server
local require = import and import(...) or require
local log = log and log(...) or print

local crypt = require "crypt"

local pack = require "pack"
local fileprocess = require "fileprocess"

local client = {}; client.__index = client

--the dir hold the files
local sand_box_path = ""

local logic_request = {}
--file data stored in mem, e.g. remote required file
local mem_file = {}
local mem_file_status = {}
local current_reading = ""

local _linda = nil

---------------------------------------------------
local clientcommand = {}
--cmd while recieving data from server
--there are two types of file data
--one will store as file
--one will store in the memory
--the data stored in the memory will have record in mem_file_status
function clientcommand.FILE(resp, self)
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
        --file dose not exist on server
        local hash = resp[3]

        print("write file", file_path, hash)
        if not hash then
            --TODO: handle this situation
            print("error: server hash not founc")
            return
        end

        --print("package info", resp[1], resp[2],resp[4], resp[5])
        --if is the first package, will delete the origin file
        --if is other package, will add to the existing file
        --TODO: consider if the order is not correct
        if offset <= fileprocess.MAX_CALC_CHUNK then
            self.vfs:write(hash, resp[5])
        else
            self.vfs:write(hash, resp[5], "ab")
        end

        if offset >= total_pack then
            --TODO version management/control
            --the file is complete, inform out side
            print("get new file: "..file_path)
            _linda:send("new file", file_path)
        end

        print("write file", file_path, hash)
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
function clientcommand.ERROR(resp, self)
    for k, v in pairs(resp) do
        print(k, v)
    end
    _linda:send("mem_data", "ERROR")
end

function clientcommand.EXIST_CHECK(resp, self)
    assert(resp[1] == "EXIST_CHECK", "COMMAND: "..resp[1].." invalid, shoule be EXIST_CHECK")
    local result = resp[2]
    print("get exist check result: "..tostring(result))

    _linda:send("file exist", result)
end

function clientcommand.DIR(resp, self)

    print(resp[1], resp[2], resp[3], resp[4])

end

function clientcommand.RUN(resp, self)
    _linda:send("log", {"Bgfx", "get run command", resp[1], resp[2]})
    _linda:send("run", resp[2])
end

function clientcommand.SCREENSHOT(resp, self)
    print("get screenshot command")

    --resp[1] is "SCREENSHOT"
    --resp[2] screenshot id
    --todo maybe more later

    _linda:send("screenshot_req", resp)
end

---------------------------------------------------

local receive_cmd = {}
--register client command
do
    for cmd, func in pairs(clientcommand) do
        --prevent duplicate cmd
        assert(receive_cmd[cmd] == nil)
        --print("client cmd:",cmd, "func:",func)
        receive_cmd[cmd] = func

    end
end

local iosys = require "iosys"

function client.new(address, port, init_linda, pkg_dir, sb_dir, io_repo)
    --connection started from here
    print("listen to address", address,"port", port)
    local io_ins = iosys.new()
    local id = tostring(address) .. ":" .. tostring(port)
    assert(io_ins:Bind(id), "bind to: ".. id .. " failed")

    _linda = init_linda
    sand_box_path = sb_dir .. "/Documents/"

    print("create server repo")

    --create vfs
    --return setmetatable( { host = fd, fds = {fd}, sending = {}, resp = {}, reading = ""}, client)
    return setmetatable({id = id, linda = init_linda, io = io_ins, connect = {}, vfs = io_repo}, client)
end

function client:register_command(cmd, func)
    --register command from other files
    receive_cmd[cmd] = func
end

function client:send(...)
    local client_req = { ...}

    local cmd = client_req[1]
    if cmd == "REQUIRE" then
        --TODO add hash check?
        --cmd for server should be the same
        --however, the client may handle differently
        --client_req[1] = "GET"
        local file_path = client_req[2]
        mem_file_status[file_path] = "pending"
        mem_file[file_path] = ""
        current_reading = file_path
    end

    --need to calculate the sha1 value
    --table.insert(self.sending, pack.pack(client_req))
    if self.current_connect then
        self.io:Send(self.current_connect, client_req)
    end
end

local max_screenshot_pack = 64*1024 - 100

function client:CollectRequest()
    local count = 0
    --this if for client request
    while true do
        local key, value = _linda:receive(0.001, "request", "log", "screenshot", "vfs_open")
        if key == "request" then
            --calculate sha1 value of the request
            --if the request is already exist, ignore the latter ones
            local pack_req = pack.pack(value)
            local sha1 = crypt.hexencode(crypt.sha1(pack_req))

            --table.insert(logic_request,value)
            --count = count + 1

            if not logic_request[sha1] then
                logic_request[sha1] = value
                count = count + 1
            end

            --for now, hard coded a 10 request limit per update
            if count == 10 then
                break
            end
        elseif key == "log" then
            --table.insert(self.sending, pack.pack({"LOG", table.unpack(value)}))

            if self.current_connect then
                self.io:Send(self.current_connect, {"LOG", table.unpack(value)})
            else
                if not self.log_cache then self.log_cache = {} end
                table.insert(self.log_cache, value)
            end

        elseif key == "screenshot" then
            --after compression, only have name and data string
            --value[2] is data
            local name = value[1]
            local size = #value[2]
            --print("recv ss", name, size, width, height,pitch)

            local offset = 0
            while offset < size do
                --print("add a pack", offset)
                local rest_size = size - offset
                local pack_data_size = math.min(rest_size, max_screenshot_pack)
                local pack_str = string.sub(value[2], offset + 1, pack_data_size + offset)

                offset = offset + pack_data_size
                --table.insert(self.sending, pack.pack({"SCREENSHOT", name, size, offset, pack_str}))
                if self.current_connect then
                    self.io:Send(self.current_connect, {"SCREENSHOT", name, size, offset, pack_str})
                end
            end
        elseif key == "vfs_open" then
            print("try open: ", value)
            local file, hash, f_n = self.vfs:open(value)
            print("vfs open res:", file, hash, f_n)
            if file then file:close() end
            --FILE can't send through linda
            self.linda:send("vfs_open_res", {f_n, hash})
        else
            break
        end
    end

end

function client:mainloop(timeout)
    local n_connect, n_disconnect = self.io:Update()
    --find new connection
    if n_connect and #n_connect > 0 then
        for _, v in ipairs(n_connect) do
            self.connect[v] = true

            --auto request root
            print("request root: " .. v)
            self.io:Send(v, {"REQUEST_ROOT"})

            if not self.current_connect then
                self.current_connect = v    -- default send to this id

                if self.log_cache then
                    for _, l in ipairs(self.log_cache) do
                        self.io:Send(self.current_connect, {"LOG", table.unpack(l)})
                    end
                end
            end
        end
    end

    --find new disconnection
    if n_disconnect and #n_disconnect > 0 then
        for _, v in ipairs(n_disconnect) do
            self.connect[v] = nil

            --if current connection failed, set current_connect to other connection(or nil if don't have any)
            if v == self.current_connect then
                self.current_connect = nil
                for k, _ in pairs(self.connect) do
                    self.current_connect = k
                    break
                end
            end
        end
    end

    self:CollectRequest()
    for key, req in pairs(logic_request) do
        local cmd = req[1]

        if cmd == "REQUIRE" then

            local file_name = req[2]

            local cache_status = mem_file_status[file_name]
            --if the cache does not exist, then send the request info
            --TODO: hash check??
            if not cache_status then
                self:send(table.unpack(req))
            elseif cache_status == "FINISHED" then
                _linda:send("mem_data", mem_file[file_name])
                logic_request[key] = nil
            end
            --other in status like "RUNNING", do nothing but wait

        else --if cmd == "GET" or cmd == "LIST" then
            --simply send the request, does not bother if it already had it
            --or it need to load the file
            self:send(table.unpack(req))
        end
    end

    for k, _ in pairs(self.connect) do
        local recv_package = self.io:Get(k)
        --process request
        for _, recv in ipairs(recv_package) do
            local cmd = recv[1]
            if cmd == "SERVER_ROOT" then
                self.vfs:changeroot(recv[2])

                ---do self update
                print("get new conneciton ")
                self.linda:send("new connection", true)
            else
                local func = receive_cmd[cmd]
                if not func then
                    print("unknown command", cmd)
                end

                func(recv, self)
            end
        end
    end

    for i,_ in pairs(logic_request) do
        logic_request[i] = nil
    end
end

return client

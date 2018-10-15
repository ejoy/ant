local client = {}; client.__index = client
local MAX_CALC_CHUNK = 62*1024
--the dir hold the files
local sand_box_path = ""

local iosys = require "iosys"
local io_cmd = {}
io_cmd.EXIST_CHECK = function(resp, self)
    assert(resp[1] == "EXIST_CHECK", "COMMAND: "..resp[1].." invalid, shoule be EXIST_CHECK")
    local result = resp[2]

    self.linda:send("file exist", result)
end

io_cmd.FILE = function(resp, self)
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
    if offset <= MAX_CALC_CHUNK then
        self.vfs:write(hash, resp[5])
    else
        self.vfs:write(hash, resp[5], "ab")
    end

    if offset >= total_pack then
        --TODO version management/control
        --the file is complete, inform out side
        print("get new file :  "..file_path)
        self.linda:send("new file", file_path)
    end

    print("write file", file_path, self.vfs)
end

io_cmd.SERVER_ROOT = function(resp, self)
    local cmd = resp[1]
    if cmd == "SERVER_ROOT" then
        print(pcall(self.vfs.changeroot, self.vfs, resp[2]))
        self.vfs:changeroot(resp[2])

        print("change root ant_ios", resp[2])
        if self.run_cmd_cache then
            print("restore run command", self.run_cmd_cache)
            self.linda:send("run", self.run_cmd_cache)
            self.run_cmd_cache = nil
        end

        self.linda:send("server_root_updated", true)
    end
end

io_cmd.RUN = function(resp, self)
    print("run cmd", resp[1], resp[2])
    self.run_cmd_cache = resp[2]

    print("request root")
    --self.io:Send(self.current_connect, {"REQUEST_ROOT"})
    self:send({"REQUEST_ROOT"})
    --_linda:send("run", resp[2])
end

function client.new(address, port, init_linda, pkg_dir, sb_dir, vfs_repo)
    --connection started from here
    print("listen to address", address,"port", port)
    local io_ins = iosys.new()

    local connect_id = "127.0.0.1:8889"
    local connect_res = io_ins:Connect(connect_id)
    --connect to a port, not available if this is on iOS device
    if not connect_res then
        connect_id = nil
    else
        --request root here
        io_ins:Send(connect_id, {"REQUEST_ROOT"})
    end

    local id = tostring(address) .. ":" .. tostring(port)
    assert(io_ins:Bind(id), "bind to: ".. id .. " failed")


    sand_box_path = sb_dir .. "/Documents/"

    print("create server repo")
    --return setmetatable( { host = fd, fds = {fd}, sending = {}, resp = {}, reading = ""}, client)
    return setmetatable({id = id, linda = init_linda, io = io_ins, connect = {}, vfs = vfs_repo,  connect_id = connect_id, current_connect = connect_id}, client)
end

function client:send(client_req)
    if self.current_connect then
        self.io:Send(self.current_connect, client_req)
    end
end

function client:CollectSendRequest()
    while true do
        local key, value = self.linda:receive(0.001, "io_send", "log", "vfs_open", "request")
        if key == "io_send" or key == "request" then
            self:send(value)
        elseif key == "log" then
            self:send({"LOG", table.unpack(value)})
        elseif key == "vfs_open" then
            print("try open: ", value)
            local file, hash, f_n = self.vfs:open(value)
            print("vfs open res:", file, hash, f_n)
            if file then file:close() end
            --FILE can't send through linda
            self.linda:send("vfs_open_res"..value, {f_n, hash})
            print("send file", value)
        else
            break
        end
    end

end

function client:IORecv(recv_pkg)
    for _, recv in ipairs(recv_pkg) do
        --do nothing but put it in linda, let msg process thread handle it
        print("io recv pkg", recv[1])

        local cmd = recv[1]
        local func = io_cmd[cmd]
        if not func then
            print("send msg to msg processor", cmd)
            self.linda:send("io_recv", recv)
        else
            func(recv, self)
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
            self.linda:send("new connection", true)
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

            print("disconnect from " .. v)

            --if current connection failed, set current_connect to other connection(or nil if don't have any)
            if v == self.current_connect then
                self.current_connect = nil
                for k, _ in pairs(self.connect) do
                    self.current_connect = k
                    break
                end
            end

            --server disconnected
            if v == self.connect_id then
                self.connect_id = nil
            end
        end
    end


    self:CollectSendRequest()
    for k, _ in pairs(self.connect) do
        local recv_package = self.io:Get(k)
        --process request
        self:IORecv(recv_package)
    end

    if self.connect_id then
        --handle server connection
        local recv_pkg = self.io:Get(self.connect_id)
        self:IORecv(recv_pkg)
    end
end

return client

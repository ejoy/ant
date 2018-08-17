local require = import and import(...) or require
local log = log and log(...) or print
local pack = require "pack"

local lsocket = require "lsocket"
local command_cache = {}

local iosys = require "iosys"

--give every socket a id(string), and server will only know the id not the socket itself
--if server use an id that can't be found in socket table, it should be device's udid
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

local file_server = require "fileserver"
-------------------------------------------------------------
function server:HandlePackage(response_pkg, id, self)
    --fd may be a socket, also can be a string represent the udid, treat them differently
    local cmd_type = response_pkg[1]
    if cmd_type == "MULTI_PACKAGE" then
        local file_path = response_pkg[2]
        local client_path = response_pkg[3]
        local hash = response_pkg[4]
        local file_size = response_pkg[5]
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

            self.io:Send(id, client_package)
            print("sending", file_path, "remaining", file_size - offset, #file_data)

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
    elseif cmd_type == "FILE"  or
            cmd_type == "EXIST_CHECK" or
            cmd_type == "RUN" or
            cmd_type == "ERROR" or
            cmd_type == "SCREENSHOT" or
            cmd_type == "SERVER_ROOT" then

        print("send command", cmd_type, response_pkg[2])
        self.io:Send(id, response_pkg)
        return "DONE"

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
        local status = self:HandlePackage(a_cmd, id, self)
        if status == "DONE" then
            table.insert(remove_list, k)
        end
    end

    --remove finished command
    for i = #remove_list, 1, -1 do
        table.remove(command_cache, remove_list[i])
    end

end

local enable_pack = false
function enable_pack_framework(state)
    if state then
        enable_pack = state
    end

    return enable_pack
end

--------------------------------------------------------------
function server.new(address, port, init_linda)

    winfile = require"winfile"

    winfile.exist = function(path)
        if winfile.attributes(path) then
            return true
        else
            return false
        end
    end
    winfile.open = io.open

    local io_ins = iosys.new()
    local id = tostring(address) .. ":" .. tostring(port)
    assert(io_ins:Connect(id), "connect to: " .. id .. " failed")

    local vfsrepo = require "vfsrepo"
    local server_repo = vfsrepo.new()
    print(pcall(server_repo.init, server_repo, "/Users/ejoy/Desktop/Engine/ant"))


    --server_repo:init("/Users/ejoy/Desktop/Engine/ant")
    enable_pack_framework(true)
    return setmetatable({id = id, linda = init_linda, io = io_ins, connect = {}, log = {}, vfs_repo = server_repo}, server)
end

function server:kick_client(client_id)
    if self.connect then
        self.connect[client_id] = nil
    end
    self.io:Disconnect(client_id)
end


local screenshot_cache = nil
local max_screenshot_pack = 64*1024 - 100
--store handle of lanes, check the result periodically
local function response(self, req, id)
    --print("cmd and second is ", req[1], req[2])
    local cmd = req[1]
    --if is require command, need project_directory
    if cmd == "REQUIRE" or cmd == "GET" or cmd == "EXIST" then
        --table.insert(req, project_directory)
        req.project_dir = project_directory
    end

    local func = dispatch[cmd]

    if not func then
        self:kick_client(id)  --kick
    else
        local resp = { func(req, self) }
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
                        screenshot_cache[2] = screenshot_cache[2]..data
                    end

                    if offset >= size then
                        --send data to ui screen
                        self.linda:send("response", {"SCREENSHOT", screenshot_cache})
                    end
                    --]]
                elseif a_cmd[1] == "REQUEST_ROOT" then
                    local server_root = self.vfs_repo:root_hash()
                    local command_package = {{"SERVER_ROOT", server_root}, id}
                    print("return root: ", server_root)
                    table.insert(command_cache, command_package)
                else
                    local command_package = {a_cmd, id}
                    table.insert(command_cache, command_package)
                end
            end
        end
    end
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

            local result = self.io:Connect(udid)
            if  result then
                self.connect[udid] = true
                print("connect to ".. udid .." successful")

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

    self:CheckNewDevice()
    local n_connect, n_disconnect = self.io:Update()
    if n_connect and #n_connect > 0 then
        for _, v in ipairs(n_connect) do
            self.connect[v] = true
        end
    end

    --find new disconnection
    if n_disconnect and #n_disconnect > 0 then
        for _, v in ipairs(n_disconnect) do
            print("111", v)
            print(pcall(self.kick_client, self, v))
            self:kick_client(v)

        end
    end

    --recv package
    if self.connect then
        for k, _ in pairs(self.connect) do
            local request_package = self.io:Get(k)
            --process request
            for _, req in ipairs(request_package) do
                response(self, req, k)
            end
        end
    end

    self:PackageHandleUpdate()
    self:SendLog()
    print("update finished")
end

function server:SendLog()
    for _, v in ipairs(self.log) do
        self.linda:send("log", v)
    end

    self.log = {}
end

function server:GetLindaMsg()
    while true do
        local key, value = self.linda:receive(0.001, "command", "proj dir")
        if key == "command" then
            self:HandleIupWindowRequest(value.udid, value.cmd, value.cmd_data)
        elseif key == "proj dir" then
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
    if cmd == "RUN" then
        local entrance_path = cmd_data[1]

        if udid == "all" then
            for k, _ in pairs(self.connect) do
                local request = {{"RUN", entrance_path}, k}
                print("RUN cmd sent", k, entrance_path)
                table.insert(command_cache, request)
            end
        else
            local request = {{"RUN", entrance_path}, udid}
            print("RUN cmd sent", udid, entrance_path)
            table.insert(command_cache, request)
        end

    elseif cmd == "CONNECT" then
        print("try connencting")
        --connect to device
        if self.io:Connect(udid) then
            self.connect[udid] = true
            connected_devices[udid] = true

            print("connect to ".. udid .." successful !!!!!!")
            table.insert(self.log, "connect to "..udid)
            self.linda:send("response", {"CONNECT", udid})
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
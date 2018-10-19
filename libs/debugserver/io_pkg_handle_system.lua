local ecs = ...
local world = ecs.world
local io_pkg_handle_system = ecs.system "io_pkg_handle_system"
io_pkg_handle_system.singleton "io_pkg_component"
io_pkg_handle_system.singleton "vfs_root_component"
io_pkg_handle_system.singleton "vfs_load_component"
io_pkg_handle_system.singleton "remote_log_component"

local fs = require "filesystem"

local dispatch = {}
function io_pkg_handle_system:init()
    --init commands
    for _,svr in ipairs{"debugserver.fileserver"} do
        local s = require(svr)
        for cmd, func in pairs(s) do
            assert(dispatch[cmd] == nil, "duplicate command: " .. cmd .. " found in: " .. svr)
            dispatch[cmd] = func
            print("server cmd: ".. cmd)
        end
    end

    --create a repo load cache, store command that need repo.load from vfs_repo system
    self.repo_load_cache = {}
    self.log = {}
end

local command_cache = {}

local function send_data(self, id, data_pkg)
    table.insert(self.io_pkg_component.send_pkg, {id, data_pkg})
end

local function handle_package(response_pkg, id, self)
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

            --self.io:Send(id, client_package)
            send_data(self, id, client_package)
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

        --print("send command", cmd_type, response_pkg[2], id)
        --self.io:Send(id, response_pkg)
        send_data(self, id, response_pkg)

        return "DONE"
    else
        print("cmd: " .. cmd_type .." not support yet")
        return "DONE"
    end
end

local function response(self, req, id)
    --print("cmd and second is ", req[1], req[2])
    local cmd = req[1]
    req.project_dir = fs.currentdir()   --add project directory

    local func = dispatch[cmd]

    if func then
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
                        --self.linda:send("response", {"SCREENSHOT", screenshot_cache})
                    end
                    --]]
                elseif a_cmd[1] == "REPO_CACHE" then
                    --print("insert into repo cache", a_cmd[2])
                    a_cmd.id = id
                    table.insert(self.repo_load_cache, a_cmd)
                else
                    local command_package = {a_cmd, id}
                    table.insert(command_cache, command_package)
                end
            end
        end
    else
        assert(false, "function for cmd:"..tostring(cmd).." not exist")
    end
end

local repo_load_cache_func = {}
repo_load_cache_func['EXIST_CHECK'] = function(self, hash)
    local load_req = self.vfs_load_component.load_request_queue
    if load_req[hash] then
        local real_path = load_req[hash].real_path
        if real_path then
            load_req[hash] = nil    --clear this request
            --print("io pkg found", real_path, hash)
            return {"EXIST_CHECK", real_path, hash}
        end
    end
end

function io_pkg_handle_system:update()
    local io_recv_pkg = self.io_pkg_component.recv_pkg
    for _, p in ipairs(io_recv_pkg) do
        local cnt_id = p[1]
        local pkg_data = p[2]
        --print("get package from: "..tostring(cnt_id), table.unpack(pkg_data))
        response(self, pkg_data, cnt_id)
    end
    
    self.io_pkg_component.recv_pkg = {}
    
    local function handle_repo_load_cache()
        for k, v in ipairs(self.repo_load_cache) do            
            local cache_cmd = v[2]
            local cache_func = repo_load_cache_func[cache_cmd]
            
            if cache_func then
                local data = v[3]
                local cmd_send = cache_func(self, data)
                if cmd_send then
                    local cnt_id = v.id
                    local command_package = {cmd_send, cnt_id}
                    table.insert(command_cache, command_package)
                    table.remove(self.repo_load_cache, k)
                end
            end
        end
    end
    handle_repo_load_cache()

    local function handle_package_queue()
        local remove_list = {}
        for k, v in ipairs(command_cache) do
            local a_cmd = v[1]
            local id = v[2]

            local status = handle_package(a_cmd, id, self)
            if status == "DONE" then
                table.insert(remove_list, k)
            end
        end

        for i = #remove_list, 1, -1 do
            table.remove(command_cache, remove_list[i])
        end
    end
    
    handle_package_queue()

    --send log to redirectfd, FIXME:for now just use 127.0.0.1:10000
    local function handle_log()
        for k, v in ipairs(self.log) do
            --insert into send_pkg, and send to redirectfd
            --table.insert(self.io_pkg_component.send_pkg, {"127.0.0.1:10002", v})
            table.insert(self.remote_log_component.log_queue, v)
        end
        self.log = {}
    end
    handle_log()

    --handle new command
    local function handle_pkg_func()
        for _, eid in world:each("io_pkg_handle_func_component") do
            local entity = world[eid]
            local func_com = entity.io_pkg_handle_func_component
            
            if dispatch[func_com.name] then
                print("cmd: "..func_com.name.." already exist, will be replaced")
            end

            dispatch[func_com.name] = func_com.func
            world:remove_entity(eid)
        end
    end

    handle_pkg_func()
end

local ui_command_handle_system = ecs.system "ui_command_handle"
ui_command_handle_system.singleton "io_pkg_component"
function ui_command_handle_system:init()
end

function ui_command_handle_system:update()
    for _, eid in world:each("ui_command_component") do
        print("get ui command", eid)
        local entity = world[eid]
        if entity and entity.ui_command_component then
            local ui_cmd = entity.ui_command_component
            --FIXME: for now, cmd send to all clients
            table.insert(self.io_pkg_component.send_pkg, {"all", ui_cmd.cmd})
            world:remove_entity(eid)
        end
    end
end

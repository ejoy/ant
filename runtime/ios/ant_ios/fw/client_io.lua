local client = {}; client.__index = client

--the dir hold the files
local sand_box_path = ""

local iosys = require "iosys"

function client.new(address, port, init_linda, pkg_dir, sb_dir)
    --connection started from here
    print("listen to address", address,"port", port)
    local io_ins = iosys.new()
    local id = tostring(address) .. ":" .. tostring(port)
    assert(io_ins:Bind(id), "bind to: ".. id .. " failed")

    sand_box_path = sb_dir .. "/Documents/"

    print("create server repo")
    --return setmetatable( { host = fd, fds = {fd}, sending = {}, resp = {}, reading = ""}, client)
    return setmetatable({id = id, linda = init_linda, io = io_ins, connect = {}}, client)
end

function client:send(client_req)

    if self.current_connect then
        self.io:Send(self.current_connect, client_req)
    end
end

function client:CollectSendRequest()
    --only listen to one type of message "io send"
    while true do
        local key, value = self.linda:receive(0.001, "io_send", "log")
        if key == "io_send" then
            print("io send ", table.unpack(value))
            self:send(value)
        elseif key == "log" then
            self:send({"LOG", table.unpack(value)})
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
        end
    end


    self:CollectSendRequest()
    for k, _ in pairs(self.connect) do
        local recv_package = self.io:Get(k)
        --process request
        for _, recv in ipairs(recv_package) do
            --do nothing but put it in linda, let msg process thread handle it
            print("io recv pkg", table.unpack(recv))
            self.linda:send("io_recv", recv)
        end
    end

end

return client

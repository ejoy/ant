package.path = package.path .. ";../Common/?.lua;"
package.cpath = package.cpath ..";../../../clibs/?.dll;"

local io = {}
io.__index = io

--todo: ios device does not need libimobiledevice, only server needs it
local lsocket = require "lsocket"
local pack = require "pack"
local err, imd = pcall(require, "libimobiledevicelua")
if not err then
    imd = nil   --libimobiledevicelua not avaliable, means its on client
end
PACKAGE_DATA_SIZE_ = 62*1024

local function IsUdid(name)
    --udid only contain char and number
    local pos = string.find(name, ":")
    assert(pos, "io: name format error "..name)

    if pos < 40 then
        return false
    else
        return true
    end
end

local function ToAddressPort(name)
    local s, e = string.find(name, ":%d+")
    assert(s and e, "io: name format error " .. name)

    local address = string.sub(name, 1, s-1)
    local port = tonumber(string.sub(name, s+1, e))

    return address, port
end

function io.new()
    return setmetatable({recv={}, send={}, reading = "", fds = {}}, io)
end

function io:Connect(id, type)
    --id can be "address:port" and "udid:port"
    --"address:port" example: "127.0.0.1:8888"
    --"udid:port" example: "1234567890abcdef1234567890abcdef12345678:8888", udid should be 40 chars
    print("connect id", id)
    local address, port = ToAddressPort(id)
    if IsUdid(id) then
        if imd then
            local result = imd.Connect(address, port)
            if result then
                if not self.udid then
                    self.udid = {}
                end
                --cache udid info
                self.udid[id] = true

                print("connect to "..id.." successful")
                return true
            else
                print("connect to "..id.." failed")
                return false
            end
        else
            print("libimobiledevice not avaliable")
            return false
        end
    else
        --lsocket connect
        type = type or "tcp"
        local fd = lsocket.connect(type, address, port)
        --connection failed
        if not fd then
            print("connect to "..id.." failed")
            return false
        end

        if not self.socket then
            self.socket = {}
        end

        --cache socket info
        table.insert(self.fds, fd)
        self.socket[id] = fd

        print("connect to "..id.." successful")
        return true
    end
end

function io:Bind(id, type)
    if not IsUdid(id) then
        --default tcp
        type = type or "tcp"

        local address, port = ToAddressPort(id)
        local fd = lsocket.bind(type, address, port)

        --add to fds
        if fd then
            self.host = fd
            table.insert(self.fds, fd)

            print("bind to "..id.." successful")
            return true
        else
            print("bind to "..id.." failed")
            return false
        end
    else
        --libimobiledevice do not need it
        print("can not bind to a udid")
    end
end

function io:Disconnect(id)
    if self.send then
        self.send[id] = nil
    end

    if self.recv then
        self.recv[id] = nil
    end

    if IsUdid(id) then
        if imd then
            if self.udid then
                self.udid[id] = nil
                local address, port = ToAddressPort(id)
                return imd.Disconnect(address, port)
            end
        else
            print("libimobiledevice not avaliable")
            return false
        end
    else
        if self.socket then
            local fd = self.socket[id]
            if fd then
                fd:close()
                self.socket[id] = nil
                return true
            end
        end
    end

    return false
end

function io:Send(id, data)
    --print("send package to: " .. tostring(id))
    local pkg = pack.pack(data)

    if IsUdid(id) then
        if imd then
            if self.udid and self.udid[id] then
                print("send pkg to: " .. id)

                if not self.send[id] then self.send[id] = {} end
                table.insert(self.send[id], pkg)
                return true
            end
        else
            print("libimobiledevice not avaliable")
            return false
        end
    else
        if self.socket then
            local fd = self.socket[id]
            if fd then
                if not self.send[fd] then self.send[fd] = {} end
                table.insert(self.send[fd], pkg)

                return true
            end
        end
    end

    print("cannot send to: "..id)
    return false
end

function io:Get(id)
    local pkg = {}
    if IsUdid(id) then
        if imd then
            if self.udid and self.udid[id] then
                --todo cache pkg
                if self.recv and self.recv[id] and #self.recv[id] > 0 then
                    for _, data_pkg in ipairs(self.recv[id]) do
                        local unpack_table = pack.unpack(data_pkg)
                        for _, unpack_pkg in ipairs(unpack_table) do
                            --print("get pkg", unpack_pkg)
                            table.insert(pkg, pack.unpack(unpack_pkg))
                        end
                    end

                    print("get package form: " .. id .. ", cache size: ".. #self.recv[id])
                    self.recv[id] = nil
                end
            end
        else
            print("libimobiledevice not available, can't get msg through udid")
        end
    else
        if self.socket then
            local fd = self.socket[id]
            if fd then
                if self.recv and self.recv[fd] and #self.recv[fd] > 0 then
                    --print("getting data from : " .. id)

                    for _, data_pkg in ipairs(self.recv[fd]) do
                        --print("get data package", #data_pkg)
                        table.insert(pkg, data_pkg)
                    end

                    --print("get package form: " .. id .. ", cache size: ".. #self.recv[fd])
                    self.recv[fd] = nil
                end
            end
        end
    end

    return pkg
end

function io:Select(timeout)
    if self.fds then
        return lsocket.select(self.fds, self.fds, timeout)
    end
end

--kick fd
function io:Kick(fd)
    self.socket[fd] = nil

    if self.fds then
        --client disconnect, server kick client
        for k, v in ipairs(self.fds) do
            if v == fd then
                print("kick id", k)
                table.remove(self.fds, k)
                return
            end
        end
    end
end

--update return new connect/disconnect id table
function io:Update(timeout)
    timeout = timeout or 0.005
    --lsockets
    local con_id = {}   --new connected id
    local dis_id = {}   --new disconnected id

    local rd, wt = self:Select(timeout)

    if rd then
        for _, fd in ipairs(rd) do
            if fd == self.host then
                --only server has .host variables, so only server can add new connection
                --server received new connection
                local new_fd, ip, port = fd:accept()
                local new_id = ip .. ":"..tostring(port)
                print("accept new id: "..new_id)

                table.insert(self.fds, new_fd)
                table.insert(con_id, new_id)

                if not self.socket then
                    self.socket = {}
                end

                self.socket[new_id] = new_fd
            else
                --receive and cache package
                if not self.recv[fd] then self.recv[fd] = {} end

                --insert recv package to queue
                local recv_data = fd:recv()
                if recv_data then
                    --print("get data from fd: ", tostring(fd))

                    self.reading = self.reading .. recv_data
                    local off = 1
                    local len = #self.reading
                    while off < len do
                        local ok, str, idx = pcall(string.unpack,"<s2", self.reading, off)
                        if ok then
                            --table.insert(resp, pack.unpack(str))
                            off = idx

                            local unpack_str = pack.unpack(str)
                            table.insert(self.recv[fd], unpack_str)
                        else
                            break
                        end
                    end

                    self.reading = self.reading:sub(off)

                    --  table.insert(self.recv[fd], recv_data)
                else
                    print("need kick", fd)
                    local d_id
                    for k, v in pairs(self.socket) do
                        if v == fd then

                            d_id = k
                            print(k, v)
                            break
                        end
                    end

                    if d_id then
                        table.insert(dis_id, d_id)
                        self:Kick(fd)
                    else
                        assert(false)
                    end

                end
            end
        end
    end

    if wt then
        for _, fd in ipairs(wt) do
            if fd then
                --send package
                if self.send[fd] and #self.send[fd] > 0 then
                    --print("send cache", self.send[fd])
                    pack.send(fd, self.send[fd])
                end
                --   pack.send(fd, {pack.pack({"LOG", "test"})})
            end
        end
    end


    --send and recv key will be udid, other then these mostly the same

    if self.udid and imd then
        for udid,_ in pairs(self.udid) do
            --recv
            if not self.recv[udid] then self.recv[udid] = {} end

            local address, port = ToAddressPort(udid)
            local recv_data = imd.Recv(address, port, timeout*1000)

            if recv_data then
                table.insert(self.recv[udid], recv_data)
            end

            --send
            if self.send then
                local udid_send = self.send[udid]
                if udid_send and #udid_send > 0 then
                    for _, pkg in ipairs(udid_send) do
                        if imd.Send(address, port, pkg) then
                            print("send pkg to: "..udid .. " succeed" )
                        else
                            print("send pkg to udid: ".. udid .. " failed")
                        end
                    end
                end

                self.send[udid] = {}
            end
        end
    end

    return con_id, dis_id
end

return io
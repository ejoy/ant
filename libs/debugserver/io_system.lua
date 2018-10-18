local ecs = ...
local world = ecs.world
local io_system = ecs.system "io_system"
io_system.singleton "io_pkg_component"

package.path = package.path .. ";libs/dev/Common/?.lua;"
local iosys = require "iosys"

--only deal with receive and send io packages, create entity with io_pkg_component
function io_system:init()
    log("init io system")
    local address = "127.0.0.1"
    local port = 8889

    self.io = iosys.new()
    local server_id = tostring(address) .. ":" .. tostring(port)
    log("bind to id: " .. server_id)

    assert(self.io:Bind(server_id), "bind to: " .. server_id .. " failed")
    log("init server cloud successful")

    self.id = server_id
    self.connect = {}

    enable_pack_framework(true)
end

local function kick_client(self, v)
    self.io:Disconnect(v)
    self.connect[v] = nil
end

function io_system:update()
    local n_connect, n_disconnect = self.io:Update()
    --handle new connection added and/or new disconnection
    if n_connect and #n_connect>0 then
        for _, v in ipairs(n_connect) do
            log("new connection: "..v)
            self.connect[v] = true
        end
    end

    if n_disconnect and #n_disconnect>0 then
        for _, v in ipairs(n_disconnect) do
            log("disconnect from: "..v)
            kick_client(self, v)
        end
    end

    --receiving packages
    for name, _ in pairs(self.connect) do
        local request_package = self.io:Get(name)
        for _, req in ipairs(request_package) do
            table.insert(self.io_pkg_component.recv_pkg, {name, req})
        end
    end

    --send packages
    local send_pkg_queue = self.io_pkg_component.send_pkg
    for _, pkg in ipairs(send_pkg_queue) do
        local id = pkg[1]
        local data = pkg[2]
        if id ~= "all" then            
            self.io:Send(id, data)
        else
            for c_id, _ in pairs(self.connect) do
                self.io:Send(c_id, data)
            end
        end
    end
    self.io_pkg_component.send_pkg = {}
end

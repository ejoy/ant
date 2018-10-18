local ecs = ...
local world = ecs.world

local server_debug_system = ecs.system "server_debug_system"
server_debug_system.singleton "io_pkg_component"

function server_debug_system:init()
    local dbg_tcp = (require "debugger.io.tcp_server")('127.0.0.1', 4278)
    
    dbg_tcp:event_in(function(data)
        --server_framework:SendPackage({"dbg", data})
        print("dbg event in")
        table.insert(self.io_pkg_component.send_pkg, {"dbg",data})
    end)

    dbg_tcp:event_close(function()
        --server_framework:SendPackage({"dbg", ""})
        print("dbg event close")
        table.insert(self.io_pkg_component.send_pkg, {"dbg", ""})
    end)

    local eid = world:new_entity("io_pkg_handle_func_component")
    local entity = world[eid]
    entity.io_pkg_handle_func_component.name = "dbg"
    entity.io_pkg_handle_func_component.func = function(data_table) dbg_tcp:send(data_table[2]) end

    self.dbg_tcp = dbg_tcp
end

function server_debug_system:update()
    self.dbg_tcp:update()
end

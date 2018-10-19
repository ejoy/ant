local ecs = ...
local world = ecs.world

local remote_log_component = ecs.component "remote_log_component" {}

local remote_log_system = ecs.system "remote_log_system"
remote_log_system.singleton "remote_log_component"

function remote_log_system:init()
    self.remote_log_component.log_queue = {}
end

function remote_log_system:update()
    local log_queue = self.remote_log_component.log_queue

    for _, log in ipairs(log_queue) do
        local cat, thread, time = log[1], log[2], log[3]
        local log_data = table.concat({table.unpack(log, 4)}, " ") .. "\n"

        if redirectfd_table and redirectfd_table[thread] then
            redirectfd_table[thread].ofd:send(log_data)
        end
    end

    self.remote_log_component.log_queue = {}
end
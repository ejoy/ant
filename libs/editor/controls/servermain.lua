local ecs = require "ecs"
local asset = require "asset"
local task = require "editor.task"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"

local server_main = {}
server_main.__index = server_main
--some ui control

function server_main:new_world(modules)
    self.world = ecs.new_world {
        modules = modules,
        module_path = 'libs/?.lua;libs/?/?.lua;',
        update_order = {"timesystem"},
        update_bydepend = true,

        --fb will just be 0
        args = {mq = self.iq, fb_size = {w=0, h=0}},
    }

    task.loop(self.world.update)
end

function server_main:new_ui_command(cmd_pkg)
    if self.world then
        print("create command", table.unpack(cmd_pkg))
        local eid = self.world:new_entity("ui_command_component")
        local entity = self.world[eid]

        if entity and entity.ui_command_component then
            entity.ui_command_component.cmd = cmd_pkg
        end
    end
end

return server_main
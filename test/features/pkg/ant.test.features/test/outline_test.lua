local ecs   = ...
local world = ecs.world
local w     = world.w

local util  = ecs.require "util"
local PC    = util.proxy_creator()
local common = ecs.require "common"
local ot_sys = common.test_system "outline"

local iol = ecs.require "ant.outline|outline"

local outline_prefab

function ot_sys.init_world()
    PC:create_instance {
        prefab = "/pkg/ant.test.features/assets/entities/outline_duck.prefab",
    }
end

local kb_mb = world:sub{"keyboard"}

function ot_sys.data_changed()
    for _, key, press in kb_mb:unpack() do
        if key == "L" and press == 0 then
            local ee = world:entity(outline_prefab.tag['*'][1], "outline_info:in")
            iol.update_outline_color(ee, {0, 1, 0, 1})
            iol.update_ouline_scale(ee, 0.8)
        end
    end
end

function ot_sys:exit()
    PC:clear()
end

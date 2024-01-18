local ecs   = ...
local world = ecs.world
local w     = world.w

local util  = ecs.require "util"

local ot_sys = ecs.system "outline_test_system"

local oueline_prefab

function ot_sys.init_world()
    oueline_prefab = util.create_instance  "/pkg/ant.test.features/assets/entities/outline_duck.prefab"
    --util.create_instance  "/pkg/ant.test.features/assets/entities/outline_wind.prefab" 
end

local kb_mb = world:sub{"keyboard"}

function ot_sys.data_changed()
    for _, key, press in kb_mb:unpack() do
        if key == "L" and press == 0 then
            --TODO: need fix
            local ee <close> = world:entity(oueline_prefab.tag['*'][1], "outline_remove?update")
            ee.outline_remove = true
        end
    end
end
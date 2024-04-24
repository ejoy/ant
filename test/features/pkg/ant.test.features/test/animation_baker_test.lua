local ecs   = ...
local world = ecs.world
local w     = world.w

local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()
local iab   = ecs.require "ant.animation_baker|animation_baker"

local ab_test_sys = common.test_system "animation_baker"

function ab_test_sys:init()
    PC:create_instance {
        prefab = "/pkg/ant.test.features/assets/zombies/1-appear.glb/mesh.prefab",
        on_ready = function (p)
            util.set_prefab_srt(p, 0.1)
        end
    }

    local eid = iab.create "/pkg/ant.test.features/assets/zombies/1-appear.glb/mesh.prefab"

end
local ecs   = ...
local world = ecs.world
local w     = world.w

local common = ecs.require "common"
local empty_test_sys = common.test_system "empty"

local PC = ecs.require "util"
--common.init_system = "empty"

function empty_test_sys:preinit()
    
end

function empty_test_sys:init()
    -- PC:create_instance {
    --     prefab = "/pkg/ant.test.features/assets/skeleton_test.glb|mesh.prefab"
    -- }
end

function empty_test_sys:exist()
    PC:clear()
end
local ecs   = ...
local world = ecs.world
local w     = world.w
local sb_sys = ecs.system "shadow_bounding_system"
local math3d    = require "math3d"

function sb_sys:init()
    world:create_entity {
        policy = {
            "ant.shadow_bounding|shadow_bounding",
        },
        data = {
            shadow_bounding = {}
        }
    }
end


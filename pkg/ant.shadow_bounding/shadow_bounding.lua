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
            shadow_bounding = {
                scene_aabb  = math3d.marked_aabb(math3d.vector(-1e9, -1e9, -1e9), math3d.vector(1e9, 1e9, 1e9)),
                camera_aabb = math3d.marked_aabb(math3d.vector(-1e9, -1e9, -1e9), math3d.vector(1e9, 1e9, 1e9))
            }
        }
    }
end


local ecs   = ...
local world = ecs.world
local w     = world.w

local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()
local iab   = ecs.require "ant.animation_baker|animation_baker"
local math3d= require "math3d"

local ab_test_sys = common.test_system "animation_baker"

local abo

function ab_test_sys:init()
    -- PC:create_instance {
    --     prefab = "/pkg/ant.test.features/assets/zombies/1-appear.glb/mesh.prefab",
    --     on_ready = function (p)
    --         util.set_prefab_srt(p, 0.1)
    --     end
    -- }

    abo = iab.create("/pkg/ant.test.features/assets/zombies/1-appear.glb/mesh.prefab", {
        {
            s = 1,
            r = math3d.quaternion{0, math.pi*0.3, 0},
            t = math3d.vector(1, 0, 0, 1),
            frame = 0,
        },
        {
            s = 2,
            r = math3d.quaternion{0,-math.pi*0.3, 0},
            t = math3d.vector(-1, 0, 0, 1),
            frame = 1,
        }
    }, 4)
end

local kb_mb = world:sub{"keyboard"}

function ab_test_sys:data_changed()
    assert(abo)
    for _, key, press in kb_mb:unpack() do
        if press == 0 and key == "C" then
            iab.update_frames(abo, {
                3, 2
            })
        end
    end
end
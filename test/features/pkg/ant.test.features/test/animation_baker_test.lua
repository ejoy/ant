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
            s = 0.1,
            r = math3d.quaternion{0, math.pi*0.3, 0},
            t = math3d.vector(3, 2, 0, 1),
            frame = 0,
        },
        {
            s = 0.2,
            r = math3d.quaternion{0,-math.pi*0.3, 0},
            t = math3d.vector(-3, 2, 0, 1),
            frame = 1,
        }
    }, 4)

    util.create_shadow_plane(10, 10)
end

local kb_mb = world:sub{"keyboard"}

function ab_test_sys:data_changed()
    if abo then
        for _, key, press in kb_mb:unpack() do
            if press == 0 and key == "C" then
                iab.update_frames(assert(abo.Armature_Take_001_BaseLayer), {
                    3, 2
                })
            end
        end
    end
end

function ab_test_sys:render_submit()
    iab.dispatch(abo.Armature_Take_001_BaseLayer)
end

function ab_test_sys:exit()
    if abo then
        iab.destroy(abo)
    end

    PC:clear()
end
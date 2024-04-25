local ecs   = ...
local world = ecs.world
local w     = world.w

local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()
local iai   = ecs.require "ant.animation_instances|animation_instances"
local math3d= require "math3d"

local ai_test_sys = common.test_system "animation_instances"

local abo

local function many_instances(prefab)
    local s = 0.01
    local dx, dz = 0.5, 0.5
    local instances = {}

    local bakenum = 30
    local h = 1

    local numx, numz = 16, 32
    local half_numx, half_numz = numx//2, numz//2

    for i=1, numz do
        local z = ((i-1)-half_numz)*dz
        for j=1, numx do
            local x = ((j-1)-half_numx)*dx

            instances[#instances+1] = {
                frame   = math.random(0, bakenum-1),
                s       = s,
                t       = {x, h, z, 1}
            }
        end
    end

    return iai.create(prefab, bakenum, #instances, instances)
end

local function two_instances(prefab)
    return iai.create(prefab, 4, 2, {
        {
            s = 0.1,
            r = {0, math.pi*0.3, 0},
            t = {3, 2, 0, 1},
            frame = 0,
        },
        {
            s = 0.2,
            r = {0,-math.pi*0.3, 0},
            t = {-3, 2, 0, 1},
            frame = 1,
        }
    })
end


function ai_test_sys:init()
    -- PC:create_instance {
    --     prefab = "/pkg/ant.test.features/assets/zombies/1-appear.glb/mesh.prefab",
    --     on_ready = function (p)
    --         util.set_prefab_srt(p, 0.1)
    --     end
    -- }

    --abo = two_instances "/pkg/ant.test.features/assets/zombies/1-appear.glb/ani_bake.prefab"
    abo = many_instances "/pkg/ant.test.features/assets/zombies/1-appear.glb/ani_bake.prefab"

    util.create_shadow_plane(10, 10)
end

local kb_mb = world:sub{"keyboard"}

function ai_test_sys:data_changed()
    if abo then
        for _, key, press in kb_mb:unpack() do
            if press == 0 and key == "C" then
                iai.update_offset(assert(abo.Armature_Take_001_BaseLayer), 1)
            end
        end
    end
end

function ai_test_sys:exit()
    if abo then
        iai.destroy(abo)
    end

    PC:clear()
end
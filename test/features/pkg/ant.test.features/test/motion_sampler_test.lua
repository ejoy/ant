local ecs       = ...
local world     = ecs.world
local w         = world.w
local math3d    = require "math3d"

local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()

local ms_test_sys   = common.test_system "motion_sampler"

local ims           = ecs.require "ant.motion_sampler|motion_sampler"
local itimer        = ecs.require "ant.timer|timer_system"
local ig            = ecs.require "ant.group|group"

local function motion_sampler_test()
    local sampler_group = ims.sampler_group()
    local eid = PC:create_entity {
        group = sampler_group,
        policy = {
            "ant.scene|scene_object",
            "ant.motion_sampler|motion_sampler",
        },
        data = {
            scene = {},
            motion_sampler = {
                duration = 10000,
                current = 0,
                keyframes = {
                    {r = math3d.quaternion{0.0, 0.0, 0.0}, t = math3d.vector(0.0, 0.0, 0.0), step = 0.0},
                    {                                      t = math3d.vector(1.0, 0.0, 2.0), step = 0.5},
                    {r = math3d.quaternion{0.0, 1.2, 0.0}, t = math3d.vector(0.0, 0.0, 2.0), step = 1.0}
                }
            }
        }
    }

    ig.enable(sampler_group, "view_visible", true)

    PC:create_instance {
        prefab = "/pkg/ant.resources.binary/meshes/Duck.glb|mesh.prefab",
        parent = eid,
        group = sampler_group,
    }
end

function ms_test_sys:init()
    motion_sampler_test()
end

local kb_mb = world:sub {"keyboard"}

function ms_test_sys:data_changed()
    local mse = w:first "motion_sampler:update"
    if mse then
        local ms = mse.motion_sampler
        if ms.duration < 0 then
            for _, key, press in kb_mb:unpack() do
                if key == "P" and press == 0 then
                    ims.set_keyframes(mse,
                        {t = math3d.vector(0.0, 0.0, 0.0), 0.0},
                        {t = math3d.vector(0.0, 0.0, 2.0), 1.0}
                    )
                end
            end

            local tenSecondMS<const> = 10000
            ims.set_ratio(mse, (itimer.current() % tenSecondMS) / tenSecondMS)
        end
    end
end

function ms_test_sys:exit()
    PC:clear()
end
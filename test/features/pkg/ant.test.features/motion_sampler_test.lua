local ecs       = ...
local world     = ecs.world
local w         = world.w
local math3d    = require "math3d"

local ms_test_sys   = ecs.system "motion_sampler_test_system"

local ims           = ecs.require "ant.motion_sampler|motion_sampler"
local itimer        = ecs.require "ant.timer|timer_system"

local function motion_sampler_test()
    local sampler_group = ims.sampler_group()
    local eid = world:create_entity({
        policy = {
            "ant.scene|scene_object",
            "ant.motion_sampler|motion_sampler",
            "ant.general|name",
        },
        data = {
            scene = {},
            name = "motion_sampler",
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
    }, sampler_group)

    world:group_enable_tag("view_visible", sampler_group)
    world:group_flush "view_visible"

    local p = world:create_instance("/pkg/ant.resources.binary/meshes/Duck.glb|mesh.prefab", eid, sampler_group)
    world:create_object(p)
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

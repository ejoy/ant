local ecs   = ...
local world = ecs.world
local w     = world.w
local mathpkg=import_package "ant.math"
local mc    = mathpkg.constant

local lms   = ecs.clibs "motion.sampler"

local itimer= ecs.import.interface "ant.timer|itimer"

local cms = ecs.component "motion_sampler"

local function init_ms()
    return {
        duration    = 0.0,
        ratio       = 0.0,

        source_s    = mc.NULL,
        source_r    = mc.NULL,
        source_t    = mc.NULL,

        target_s    = mc.NULL,
        target_r    = mc.NULL,
        target_t    = mc.NULL,
    }
end

function cms.init(s)
    assert(not s)
    return init_ms()
end

function cms.remove()
    
end

function cms.marshal()
    return ""
end

function cms.unmarshal()
    return init_ms()
end

local motion_sampler_group<const> = 101010

local mss = ecs.system "motion_sample_system"

function mss:entity_init()
end

function mss:do_motion_sample()
    lms.sample(motion_sampler_group, itimer.delta())
end

local ims = ecs.interface "imotion_sample"

function ims.sampler_group()
    return ecs.group(motion_sampler_group)
end

function ims.set_duration(e, duration)
    w:extend(e, "motion_sampler:update")
    e.motion_sampler.duration = duration
end

function ims.set_target(e, s, r, t, duration)
    w:extend(e, "motion_sampler:update scene:in")
    local ss = e.motion_sampler
    if duration then
        ss.duration     = duration
    end
    
    ss.ratio        = 0.0

    ss.target_s     = s or mc.NULL
    ss.target_r     = r or mc.NULL
    ss.target_t     = t or mc.NULL

    local scene = e.scene

    ss.source_s     = scene.s
    ss.source_r     = scene.r
    ss.source_t     = scene.t

    w:submit(e)
end
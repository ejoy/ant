local ecs   = ...
local world = ecs.world
local w     = world.w
local mathpkg=import_package "ant.math"
local mc    = mathpkg.constant
local math3d= require "math3d"

local lms   = ecs.clibs "motion.sampler"

local itimer= ecs.import.interface "ant.timer|itimer"

local cms = ecs.component "motion_sampler"

local function init_ms()
    return {
        duration    = 0.0,
        deltatime   = 0.0,

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

local function check_remove_m3d(m)
    if m ~= mc.NULL then
        math3d.unmark(m)
    end
end

function cms.remove(s)
    check_remove_m3d(s.source_s)
    check_remove_m3d(s.source_r)
    check_remove_m3d(s.source_t)

    check_remove_m3d(s.target_s)
    check_remove_m3d(s.target_r)
    check_remove_m3d(s.target_t)
end

function cms.marshal()
    return ""
end

function cms.unmarshal()
    return init_ms()
end

local motion_sampler_group<const> = 101010

local mss = ecs.system "motion_sampler_system"

function mss:entity_init()
end

function mss:do_motion_sample()
    lms.sample(motion_sampler_group, itimer.delta())
end

local ims = ecs.interface "imotion_sampler"

function ims.sampler_group()
    return ecs.group(motion_sampler_group)
end

function ims.set_duration(e, duration)
    w:extend(e, "motion_sampler:update")
    e.motion_sampler.duration = duration
end

local function tom3d(old, new)
    if old ~= mc.NULL then
        math3d.unmark(old)
    end
    if new then
        return math3d.mark(new)
    end

    return mc.NULL
end

function ims.set_target(e, s, r, t, duration)
    w:extend(e, "motion_sampler:update scene:in")
    local ss = e.motion_sampler
    if duration then
        ss.duration = duration
    end
    
    ss.deltatime    = 0.0

    ss.target_s     = tom3d(ss.target_s, s)
    ss.target_r     = tom3d(ss.target_r, r)
    ss.target_t     = tom3d(ss.target_t, t)

    local scene = e.scene

    --we need to copy it
    ss.source_s     = tom3d(ss.source_s, math3d.vector(scene.s))
    ss.source_r     = tom3d(ss.source_r, math3d.quaternion(scene.r))
    ss.source_t     = tom3d(ss.source_t, math3d.vector(scene.t))

    w:submit(e)
end
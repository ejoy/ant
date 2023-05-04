local ecs   = ...
local world = ecs.world
local w     = world.w
local mathpkg=import_package "ant.math"
local mc    = mathpkg.constant
local math3d= require "math3d"

local lms   = ecs.clibs "motion.sampler"
local ltween = require "motion.tween"

local itimer= ecs.import.interface "ant.timer|itimer"

local cms = ecs.component "motion_sampler"

local function init_ms()
    return {
        duration    = 0.0,
        deltatime   = 0.0,
        ratio       = 0.0,

        tween_in    = 0,
        tween_out   = 0,

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
    --ms.ratio = tween(std::min(1.f, ms.deltatime / ms.duration), (tween_type)ms.tween_in, (tween_type)ms.tween_out);

    local g = ecs.group(motion_sampler_group)
    g:enable "motion_sampler_tag"
    ecs.group_flush()

    local dt = itimer.delta()
    for e in w:select "motion_sampler:update scene_needchange?update" do
        local ms = e.motion_sampler
        if ms.duration >= 0 and ms.deltatime <= ms.duration then
            ms.deltatime = ms.deltatime + dt
            ms.ratio = ltween.interp(math.min(1.0, ms.deltatime / ms.duration), ms.tween_in, ms.tween_out)
            e.scene_needchange = true
        end
    end

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

function ims.set_target(e, s, r, t, duration, tween_in, tween_out)
    w:extend(e, "scene:in")
    local scene = e.scene
    ims.set_target_ex(e, {s = math3d.vector(scene.s), r = math3d.quaternion(scene.r), t = math3d.vector(scene.t)}, {s = s, r = r, t = t}, duration, tween_in, tween_out)
end

function ims.set_target_ex(e, src, dst, duration, tween_in, tween_out)
    w:extend(e, "motion_sampler:update")
    local ss = e.motion_sampler
    if duration then
        ss.duration = duration
    end

    ss.deltatime    = 0.0

    ss.tween_in     = tween_in or mc.TWEEN_NONE
    ss.tween_out    = tween_out or mc.TWEEN_NONE

    ss.target_s     = tom3d(ss.target_s, dst.s)
    ss.target_r     = tom3d(ss.target_r, dst.r)
    ss.target_t     = tom3d(ss.target_t, dst.t)

    --we need to copy it
    ss.source_s     = tom3d(ss.source_s, src.s)
    ss.source_r     = tom3d(ss.source_r, src.r)
    ss.source_t     = tom3d(ss.source_t, src.t)

    w:submit(e)
end

function ims.set_ratio(e, ratio)
    w:extend(e, "motion_sampler:update scene_needchange?update")
    if e.motion_sampler.duration >= 0 then
        error "set motion_sampler ratio need duration is less than 0"
    end
    e.motion_sampler.ratio = ratio
    e.scene_needchange = true
    w:submit(e)
end
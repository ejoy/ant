local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d= require "math3d"

local lms   = world:clibs "motion.sampler"
local ltween = require "motion.tween"

local itimer= ecs.require "ant.timer|timer_system"
local ig    = ecs.require "ant.group|group"
local iom   = ecs.require "ant.objcontroller|obj_motion"

local mss = ecs.system "motion_sampler_system"

local function print_keyframes(keyframes)
    if keyframes then
        for i=1, #keyframes do
            local kf = keyframes[i]
            print("idx:", i, "step:", kf.step)
            local function m3d_str(s)
                if s then
                    return math3d.tostring(s)
                end
                return "nil"
            end
            print(("\ts:%s, r:%s, t:%s"):format(m3d_str(kf.s), m3d_str(kf.r), m3d_str(kf.t)))
        end
    end
end

local msc = ecs.component "motion_sampler"
function msc.init(v)
    local m = {}
    m.motion_tracks = v.keyframes and lms.create_tracks(v.keyframes) or lms.null()
    m.ratio = 0
    m.current = 0
    m.duration = v.duration or -1
    m.is_tick = 0
    m.stop = 0
    if m.duration >= 0 then
        m.tween_in = ltween.type(v.tween_in or "Linear")
        m.tween_out = ltween.type(v.tween_in or "Linear")
    else
        m.tween_in = ltween.type "None"
        m.tween_out = ltween.type "None"
    end
    return m
end

function msc.remove(v)
    lms.destroy_tracks(v.motion_tracks)
end

function mss:init()
    local gid = ig.register "motion_sampler"
    ig.enable(gid, "motion_sampler_tag", true)
end

local STOP_SYSTEM

function mss:do_motion_sample()
    if STOP_SYSTEM then
        return
    end
    lms.sample(ig.groupname "motion_sampler", itimer.delta())
end

local ims = {}

function ims.sampler_group()
    return ig.groupname "motion_sampler"
end


function ims.set_duration(e, duration, start, istick)
    w:extend(e, "motion_sampler:update")
    e.motion_sampler.duration = duration
    if duration >= 0 then
        e.motion_sampler.current = start or 0
        e.motion_sampler.is_tick = istick and 1 or 0
    end
    w:submit(e)
end

function ims.set_tween(e, tween_in, tween_out)
    w:extend(e, "motion_sampler:update")
    local ms = e.motion_sampler
    ms.tween_in = tween_in
    ms.tween_out = tween_out
end

local function build_tracks(ms, keyframes)
    if ms.motion_tracks == lms.null() then
        ms.motion_tracks = lms.create_tracks(keyframes)
    else
        lms.build_tracks(ms.motion_tracks, keyframes)
    end
end

local function check_keyframe_step(step)
    assert(nil ~= step, "Need specify step between [0, 1]")
    if step < 0 or step > 1.0 then
        log("Keyframe step will clamp to [0, 1]", step)
        step = math.max(0.0, math.min(1.0, step))
    end
    return step
end

function ims.set_keyframes(e, ...)
    w:extend(e, "motion_sampler:in")
    local ms = e.motion_sampler
    local keyframes = {}
    local c = select("#", ...)
    for i=1, c do
        local kf = select(i, ...)
        kf.step = check_keyframe_step(kf.step)
        keyframes[#keyframes+1] = kf
    end

    if c > 0 then
        build_tracks(ms, keyframes)
    end
end

function ims.set_target(e, target)
    w:extend(e, "motion_sampler:in scene:in")
    local keyframes = {
        {
            t=e.scene.t,
            step = 0,
        },
        {
            t=target,
            step = 1
        }
    }

    build_tracks(e.motion_sampler, keyframes)
end

function ims.set_ratio(e, ratio)
    w:extend(e, "motion_sampler:update")
    if e.motion_sampler.duration >= 0 then
        error "set motion_sampler ratio need duration is less than 0"
    end
    e.motion_sampler.ratio = ratio
    w:submit(e)
end

function ims.stop_system(stop)
    STOP_SYSTEM = stop
end

function ims.set_stop(e, stop)
    w:extend(e, "motion_sampler:update")
    e.motion_sampler.stop = stop
    w:submit(e)
end

return ims

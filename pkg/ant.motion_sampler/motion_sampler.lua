local ecs   = ...
local world = ecs.world
local w     = world.w
local mathpkg=import_package "ant.math"
local mc    = mathpkg.constant
local math3d= require "math3d"

local lms   = ecs.clibs "motion.sampler"
local ltween = require "motion.tween"

local itimer= ecs.import.interface "ant.timer|itimer"
local iom   = ecs.import.interface "ant.objcontroller|iobj_motion"

local motion_sampler_group<const> = 101010

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

function mss:component_init()
    for e in w:select "INIT motion_sampler:in" do
        local ms = e.motion_sampler

        w:extend(e, "name?in")
        print("motion_sampler:", e.name)
        print_keyframes(ms.keyframes)
        ms.motion_tracks = lms.create_tracks(ms.keyframes)

        ms.ratio = 0
        if ms.duration then
            if ms.duration >= 0 then
                ms.deltatime = 0
            end
        else
            ms.duration = -1
        end
    end
end

function mss:do_motion_sample()
    local g = ecs.group(motion_sampler_group)
    g:enable "motion_sampler_tag"
    ecs.group_flush()

    local dt = itimer.delta()
    for e in w:select "motion_sampler:update scene_needchange?update" do
        local ms = e.motion_sampler

        local needupdate = true
        if ms.duration >= 0 then
            needupdate = ms.deltatime <= ms.duration
            if needupdate then
                ms.deltatime = ms.deltatime + dt
                ms.ratio = ltween.interp(math.min(1.0, ms.deltatime / ms.duration), ms.tween_in, ms.tween_out)
            end
        end

        if needupdate then
            w:extend(e, "scene:update")
            local s, r, t = ms.motion_tracks:sample(ms.ratio)
            if s then
                iom.set_scale(e, s)
            end

            if r then
                iom.set_rotation(e, r)
            end

            if t then
                iom.set_position(e, t)
            end
            e.scene_needchange = true
        end
    end
end

local ims = ecs.interface "imotion_sampler"

function ims.sampler_group()
    return ecs.group(motion_sampler_group)
end

function ims.set_duration(e, duration)
    w:extend(e, "motion_sampler:in")
    e.motion_sampler.duration = duration
end

function ims.set_tween(e, tween_in, tween_out)
    w:extend(e, "motion_sampler:in")
    local ms = e.motion_sampler
    ms.tween_in = tween_in
    ms.tween_out = tween_out
end

function ims.set_keyframes(e, ...)
    w:extend(e, "motion_sampler:in")
    local ms = e.motion_sampler
    local keyframes = {}
    local c = select("#", ...)
    for i=1, c do
        local kf = select(i, ...)
        assert(nil ~= kf.step, "Need specify step between [0, 1]")
        if kf.step < 0 or kf.step > 1.0 then
            log("Keyframe step will clamp to [0, 1]", kf.step)
            kf.step = math.max(0.0, math.min(1.0, kf.step))
        end
        keyframes[#keyframes+1] = kf
    end

    if c > 0 then
        print_keyframes(keyframes)
        ms.motion_tracks:build(keyframes)
    end
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
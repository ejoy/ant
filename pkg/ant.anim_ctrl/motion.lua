local ecs = ...
local world = ecs.world
local w = world.w
local iom       = ecs.require "ant.objcontroller|obj_motion"
local timer     = ecs.require "ant.timer|timer_system"
local mathpkg	= import_package "ant.math"
local mu	    = mathpkg.util
local im_sys    = ecs.system "motion_system"
local im        = {}

local all_motions = {}

local testdecs0 = {
    tween_type = mu.TWEEN_LINEAR,
    duration = 1.0,
    time = 0.0,
    from = {
        postion = {0.0, 0.0, 0.0},
        scale = {1.0, 1.0, 1.0}
    },
    to = {
        postion = {0.0, 4.0, 0.0},
        scale = {2.0, 2.0, 2.0}
    },
}

local testdecs1 = {
    tween_type = mu.TWEEN_BOUNCE_OUT,
    duration = 0.5,
    time = 0.0,
    from = {
        postion = {0.0, 4.0, 0.0},
        scale = {2.0, 2.0, 2.0}
    },
    to = {
        postion = {0.0, 0.0, 0.0},
        scale = {1.0, 1.0, 1.0}
    },
}

function im.play(eid, motion_list, loop, forwards)
    all_motions[eid] = {current_midx = 1, loop = loop, forwards = forwards, motions = motion_list or {testdecs0, testdecs1}}
end

local function interp(ratio, from, to)
    return {
        from[1] + ratio * (to[1] - from[1]),
        from[2] + ratio * (to[2] - from[2]),
        from[3] + ratio * (to[3] - from[3]),
    }
end

function im_sys:data_changed()
    local delta_time = timer.delta() * 0.001
    local finished = {}
    for eid, m in pairs(all_motions) do
        local e <close> = world:entity(eid)
        local current = m.motions[m.current_midx]
        local ratio = current.time / current.duration
        if current.from.scale then
            iom.set_scale(e, interp(mu.tween[current.tween_type](ratio), current.from.scale, current.to.scale))
        end
        if current.from.rotation then
            iom.set_rotation(e, interp(mu.tween[current.tween_type](ratio), current.from.rotation, current.to.rotation))
        end
        if current.from.postion then
            iom.set_position(e, interp(mu.tween[current.tween_type](ratio), current.from.postion, current.to.postion))
        end
        current.time = current.time + delta_time
        if current.time > current.duration then
            m.current_midx = m.current_midx + 1
            if m.current_midx > #m.motions then
                m.current_midx = 1
                if not m.loop then
                    if not m.forwards then
                        local start = m.motions[1]
                        if start.from.scale then
                            iom.set_scale(e, start.from.scale)
                        end
                        if start.from.rotation then
                            iom.set_rotation(e, start.from.rotation)
                        end
                        if start.from.postion then
                            iom.set_position(e, start.from.postion)
                        end
                    end
                    finished[#finished + 1] = eid
                end
            end
            m.motions[m.current_midx].time = 0
        end
    end
    for _, eid in ipairs(finished) do
        all_motions[eid] = nil
    end
end

return im

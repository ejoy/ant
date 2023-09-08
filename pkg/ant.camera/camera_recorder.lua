local ecs = ...
local world = ecs.world
local w = world.w

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local math3d = require "math3d"
local timer = ecs.require "ant.timer|timer_system"
local icamera = ecs.require "ant.camera|camera"
local iom = ecs.require "ant.objcontroller|obj_motion"

local cr = {}
function cr.start(name)
    return world:create_entity{
        policy = {
            "ant.camera|camera_recorder",
        },
        data = {
            camera_recorder = {
                frames = {},
            },
        }
    }
end

function cr.add(e, camera_ref, idx)
    w:extend(e, "camera_recorder:in")
    local frames = e.camera_recorder.frames
    idx = idx or #frames+1

    local frustum = icamera.get_frustum(camera_ref)
    table.insert(frames, idx, {
        position = math3d.ref(iom.get_position(camera_ref)),
        rotation = math3d.ref(iom.get_rotation(camera_ref)),
        nearclip = frustum.n,
        farclip  = frustum.f,
        fov      = frustum.fov,
        duration = 2000,         --ms
        mode     = "linear",    --linear/curve
        curve    = nil, --mode should be 'curve'
    })
end

function cr.remove(e, idx)
    w:extend(e, "camera_recorder:in")
    idx = idx or #e.camera_recorder.frames
    table.remove(e.camera_recorder.frames, idx)
end

function cr.clear(e)
    w:extend(e, "camera_recorder:in")
    e.camera_recorder.frames = {}
end

function cr.stop(e)
    --TODO
end

function cr.play(e, camera_ref)
    w:extend(e, "camera_recorder:in")
    local r = e.camera_recorder
    local p = r.playing
    p.camera_ref = camera_ref
    p.cursor = 0
    world:pub{"camera_recorder", "play", e}
end

local cq_sys = ecs.system "camera_recorder_system"
local cr_play_mb = world:sub {"camera_recorder", "play"}

function cq_sys:component_init()
    for e in w:select "INIT camera_recorder:in" do
        e.camera_recorder.playing = {
            cursor = 0,
            camera_ref = nil,
        }
        
        for i, v in ipairs(e.camera_recorder.frames) do
            local tp = v.position
            local tr = v.rotation
            v.position = math3d.ref(math3d.vector(tp[1], tp[2], tp[3]))
            v.rotation = math3d.ref(math3d.quaternion(tr[1], tr[2], tr[3], tr[4]))
        end
    end
end

local playing_cr
local function play_camera_recorder()
    if playing_cr == nil then
        return
    end

    local delta_time = timer.delta()
    w:extend(playing_cr, "camera_recorder:in")
    local r = playing_cr.camera_recorder
    local frames = r.frames
    if #frames >= 2 then
        local p = r.playing
        local camera_ref = p.camera_ref

        local function which_frames(cursor)
            local duration = 0
            local numframe = #frames
            for ii=1, numframe-1 do
                local f = frames[ii]
                duration = duration + f.duration
                if cursor < duration then
                    local localcursor = cursor - (duration - f.duration)
                    return f, frames[ii+1], math.min(localcursor / f.duration, 1.0)
                end
            end
        end

        local cf, nf, t = which_frames(p.cursor)
        
        if cf then
            if cf.mode == "linear" then
                local position = math3d.lerp(cf.position, nf.position, t)
                local rotation = math3d.slerp(cf.rotation, nf.rotation, t)
                local nearclip = mu.lerp(cf.nearclip, nf.nearclip, t)
                local farclip  = mu.lerp(cf.farclip, nf.farclip, t)
                local fov      = mu.lerp(cf.fov, nf.fov, t)

                local frusutm = icamera.get_frustum(camera_ref)
                frusutm.n = nearclip
                frusutm.f = farclip
                frusutm.fov = fov
                icamera.set_frustum(camera_ref, frusutm)
                
                iom.lookto(camera_ref, position, math3d.todirection(rotation))
            else
                error(("not support interpolation mode"):format(cf.mode))
            end

            p.cursor = p.cursor + delta_time
        else
            playing_cr = nil
        end
    end
end

function cq_sys.data_changed()
    for _, _, c in cr_play_mb:unpack() do
        playing_cr = c
    end

    play_camera_recorder()
end

return cr

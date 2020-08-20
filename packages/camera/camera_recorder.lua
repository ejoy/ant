local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local math3d = require "math3d"
local timer = world:interface "ant.timer|timer"
local icamera = world:interface "ant.camera|camera"
local iom = world:interface "ant.objcontroller|obj_motion"


local cq_trans = ecs.transform "camera_recorder_transform"
function cq_trans.process_entity(e)
    e._playing = {
        cursor = 0,
        camera_eid = nil,
    }
end

local cr = ecs.interface "icamera_recorder"
function cr.start(name)
    return world:create_entity{
        policy = {
            "ant.camera|camera_recorder",
            "ant.general|name",
        },
        data = {
            frames = {},
            name = name or "camera_queue"
        }
    }
end

function cr.add(recordereid, cameraeid, idx)
    local e = world[recordereid]
    idx = idx or #e.frames+1

    local frustum = icamera.get_frustum(cameraeid)
    table.insert(e.frames, idx, {
        position = math3d.ref(iom.get_position(cameraeid)),
        rotation = math3d.ref(iom.get_rotation(cameraeid)),
        nearclip = frustum.n,
        farclip  = frustum.f,
        fov      = frustum.fov,
        duration = 2000,         --ms
        mode     = "linear",    --linear/curve
        curve    = nil, --mode should be 'curve'
    })
end

function cr.remove(recordereid, idx)
    local e = world[recordereid]
    idx = idx or #e.frames
    table.remove(e.frames, idx)
end

function cr.clear(recordereid)
    world[recordereid].frames = {}
end

function cr.stop(recordereid)
    --TODO
end

function cr.play(recordereid, cameraeid)
    local q = world[recordereid]
    local p = q._playing
    p.camera_eid = cameraeid
    p.cursor = 0
    world:pub{"camera_recorder", "play", recordereid}
end

local cq_sys = ecs.system "camera_recorder_system"
local cr_play_mb = world:sub {"camera_recorder", "play"}

local playing_cr
local function play_camera_recorder()
    if playing_cr == nil then
        return
    end

    local delta_time = timer.delta()
    local r = world[playing_cr]

    local frames = r.frames
    if #frames >= 2 then
        local p = r._playing
        local cameraeid = p.camera_eid

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

                local frusutm = icamera.get_frustum(cameraeid)
                frusutm.n = nearclip
                frusutm.f = farclip
                frusutm.fov = fov
                icamera.set_frustum(cameraeid, frusutm)
                
                iom.lookto(cameraeid, position, math3d.todirection(rotation))
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
    for _, _, creid in cr_play_mb:unpack() do
        playing_cr = creid
    end

    play_camera_recorder()
end

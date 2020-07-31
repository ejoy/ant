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
    e.frames[idx] = {
        position = math3d.ref(iom.get_position(cameraeid)),
        rotation = math3d.ref(iom.get_rotation(cameraeid)),
        nearclip = frustum.n,
        farclip  = frustum.f,
        fov      = frustum.fov,
        duration = 2000,         --ms
        mode     = "linear",    --linear/curve
        curve    = nil, --mode should be 'curve'
    }
end

function cr.remove(recordereid, idx)
    local e = world[recordereid]
    idx = idx or #e.frames
    e.frames[idx] = nil
end

function cr.stop(recordereid)
    --TODO
end

local cr_playing
function cr.play(recordereid, cameraeid)
    if cr_playing then
        print("camera queue is playing:%d, %s", cr_playing, world[cr_playing].name or "")
        return
    end

    cr_playing = recordereid
    local q = world[recordereid]
    local p = q._playing
    p.camera_eid = cameraeid
    p.cursor = 0
end

local cq_sys = ecs.system "camera_recorder_system"
local kb_mb = world:sub{"keyboard"}

local which_cr
local recording = false
function cq_sys.data_changed()
    for _, code, press, state in kb_mb:unpack() do
        if code == "RETURN" and press == 0 then 
            recording = not recording
            if recording then
                which_cr = cr.start "test1"
            else
                cr.stop(which_cr)
            end
        elseif code == "SPACE" and press == 0 then
            local ceid = world:singleton_entity "main_queue".camera_eid
            cr.add(which_cr, ceid)
        elseif state.CTRL and code == "P" and press == 0 then
            if recording then
                print("camera is recording, please stop before play")
            else
                local ceid = world:singleton_entity "main_queue".camera_eid
                cr.play(which_cr, ceid)
            end
        end
    end

    local delta_time = timer.delta()
    if cr_playing then
        local r = world[cr_playing]
        
        local frames = r.frames
        if #frames >= 2 then
            local p = r._playing
            local cameraeid = p.camera_eid

            local function which_frame(cursor)
                local duration = 0
                local numframe = #frames
                for ii=1, numframe-1 do
                    local f = frames[ii]
                    duration = duration + f.duration
                    if cursor < duration then
                        local localcursor = cursor - (duration - f.duration)
                        return ii, ii+1, math.min(localcursor / f.duration, 1.0)
                    end
                end
            end

            local cf_idx, nf_idx, t = which_frame(p.cursor)
            
            if cf_idx then
                local cf, nf = frames[cf_idx], frames[nf_idx]
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
                cr_playing = nil
            end
        end
    end
end

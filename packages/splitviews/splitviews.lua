local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"
local icamera = world:interface "ant.camera|camera"
local irender = world:interface "ant.render|irender"
local iom = world:interface "ant.objcontroller|obj_motion"
local irenderqueue = world:interface "ant.render|irenderqueue"
local svs = ecs.system "splitviews_system"

local orthoview
local mainqueue_rect = {}
local function copy_rect(rt, dst_rt)
    for k, v in pairs(rt) do dst_rt[k] = v end
end
local function backup_mainqueue_rect()
    for e in w:select "main_queue camera_eid:in render_target:in" do
        copy_rect(e.render_target.view_rect, mainqueue_rect)
    end
end

local function recover_mainqueue_rect()
    for e in w:select "main_queue camera_eid:in" do
        mainqueue_rect(mainqueue_rect, e.render_target.view_rect)
    end
end

local function rect_from_ratio(rc, ratio)
    return {
        x = rc.x + ratio.x * rc.w,
        y = rc.y + ratio.y * rc.h,
        w = rc.w * ratio.w,
        h = rc.h * ratio.h,
    }
end

function svs:entity_init()
    for e in w:select "INIT main_queue camera_eid:in render_target:in" do
        copy_rect(e.render_target.view_rect, mainqueue_rect)

        orthoview = {
            front = {
                camera_eid = icamera.create{
                    viewdir = {0, 0, 1, 0},
                    updir   = {0, 1, 0, 0},
                    eyepos  = {0, 0, -5, 0},
                    ortho   = true,
                },
                name = "ortho_front",
                view_ratio = {
                    x = 0.5, y = 0, w = 0.5, h = 0.5,
                },
            },
            back = {
                camera_eid = icamera.create{
                    viewdir = {0, 0, -1, 0},
                    updir   = {0, 1, 0, 0},
                    eyepos  = {0, 0, 5, 0},
                    ortho   = true,
                },
                name = "ortho_back",
                view_ratio = {
                    x = 0.5, y = 0, w = 0.5, h = 0.5,
                },
            },
            left = {
                camera_eid = icamera.create{
                    viewdir = {1, 0, 0, 0},
                    updir   = {0, 1, 0, 0},
                    eyepos  = {-5, 0, 0, 0},
                    ortho   = true,
                },
                name = "ortho_left",
                view_ratio = {
                    x = 0, y = 0.5, w = 0.5, h = 0.5,
                },
            },
            right = {
                camera_eid = icamera.create{
                    viewdir = {-1, 0, 0, 0},
                    updir   = {0, 1, 0, 0},
                    eyepos  = {5, 0, 0, 0},
                    ortho   = true,
                },
                name = "ortho_right",
                view_ratio = {
                    x = 0, y = 0.5, w = 0.5, h = 0.5,
                },
            },
            top = {
                camera_eid = icamera.create{
                    viewdir = {0, -1, 0, 0},
                    updir   = {0, 0, 1, 0},
                    eyepos  = {0, 5, 0, 0},
                    ortho   = true,
                },
                name = "ortho_top",
                view_ratio = {
                    x = 0.5, y = 0.5, w = 0.5, h = 0.5,
                },
            },
            bottom = {
                camera_eid = icamera.create{
                viewdir = {0, 1, 0, 0},
                updir   = {0, 0, -1, 0},
                eyepos  = {0, -5, 0, 0},
                ortho   = true,
                },
                name = "ortho_bottom",
                view_ratio = {
                    x = 0.5, y = 0.5, w = 0.5, h = 0.5,
                },
            },
        }

        for k, v in pairs(orthoview) do
            irender.create_view_queue(rect_from_ratio(mainqueue_rect, v.view_ratio), v.name, v.camera_eid)
        end
    end
end

local kb_mb = world:sub{"keyboard"}
local splitview = false
local viewidx = 1
local viewqueue = {
    {"front", "left", "bottom",},
    {"back", "right", "top",},
}

local function show_ortho_view()
    irenderqueue.set_view_rect(world:singleton_entity_id "main_queue", {x=mainqueue_rect.x, y=mainqueue_rect.y, w=mainqueue_rect.w*0.5, h=mainqueue_rect.h*0.5})

    for _, n in ipairs(viewqueue[viewidx]) do
        local v = orthoview[n]
        local eid = v.eid
        irenderqueue.set_view_rect(eid, rect_from_ratio(mainqueue_rect, v.view_ratio))
        irenderqueue.set_visible(eid, true)
    end
end

local function hide_ortho_view()
    irenderqueue.set_view_rect(world:singleton_entity_id "main_queue", mainqueue_rect)
    for _, n in ipairs(viewqueue[viewidx]) do
        local eid = orthoview[n].eid
        irenderqueue.set_visible(eid, false)
    end
end

local view_control

local svcc_mb = world:sub{"splitview", "change_camera"}

function svs:data_changed()
    for _, key, press, state in kb_mb:unpack() do
        if key == "F4" and press == 0 then
            hide_ortho_view()
            viewidx = viewidx == 2 and 1 or 2
            show_ortho_view()
        end
		if key == "F3" and press == 0 then
            splitview = not splitview
            
            if splitview then
                backup_mainqueue_rect()
                show_ortho_view()
            else
                recover_mainqueue_rect()
                hide_ortho_view()
            end
        end
        
        if key == "F2" and press == 0 then
            local vq = viewqueue[viewidx]
            if view_control == nil then
                view_control = 1
            elseif view_control == #vq then
                 view_control = nil
             else
                 view_control = view_control + 1
             end

            world:pub {
                "splitviews", "selected",
                view_control and 
                    orthoview[vq[view_control]].eid or 
                    world:singleton_entity_id "main_queue"
            }
        end

        if key == "R" and press == 0 then
            for _, n in ipairs(viewqueue[viewidx]) do
                local v = orthoview[n]
                iom.lookto(v.eid, v.eyepos, v.viewdir, v.updir)
            end
        end
    end
    
    if splitview then
        for _, _, cameraeids in svcc_mb:unpack() do
            local vq = viewqueue[viewidx]
            for idx, n in ipairs(vq) do
                irenderqueue.set_camera(orthoview[n].eid, cameraeids[idx])
            end
        end
    end
end

function svs:update_camera()
    for _, eid in world:each "orthoview" do
        local e = world[world[eid].camera_eid]
        local rc = e._rendercache
        local worldmat = rc.worldmat
        rc.viewmat = math3d.lookto(math3d.index(worldmat, 4), math3d.index(worldmat, 3), rc.updir)
        rc.projmat = math3d.projmat(rc.frustum)
        rc.viewprojmat = math3d.mul(rc.projmat, rc.viewmat)
    end
end
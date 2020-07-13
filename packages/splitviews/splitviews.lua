local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local irender = world:interface "ant.render|irender"
local iom = world:interface "ant.objcontroller|obj_motion"
local irenderqueue = world:interface "ant.render|irenderqueue"
local svs = ecs.system "splitviews_system"

local orthoview
local mainqueue_rect = {}
local function backup_mainqueue_rect()
    local mq = world:singleton_entity "main_queue"
    local vr = mq.render_target.view_rect
    mainqueue_rect.x, mainqueue_rect.y = vr.x, vr.y
    mainqueue_rect.w, mainqueue_rect.h = vr.w, vr.h
end

local function recover_mainqueue_rect()
    local mq = world:singleton_entity "main_queue"
    local vr = mq.render_target.view_rect
    vr.x, vr.y = mainqueue_rect.x, mainqueue_rect.y
    vr.w, vr.h = mainqueue_rect.w, mainqueue_rect.h
end

local function rect_from_ratio(rc, ratio)
    return {
        x = rc.x + ratio.x * rc.w,
        y = rc.y + ratio.y * rc.h,
        w = rc.w * ratio.w,
        h = rc.h * ratio.h,
    }
end

function svs:post_init()
    backup_mainqueue_rect()

    orthoview = {
        front = {
            viewdir = {0, 0, 1, 0},
            name = "ortho_front",
            view_ratio = {
                x = 0.5, y = 0, w = 0.5, h = 0.5,
            },
        },
        back = {
            viewdir = {0, 0, -1, 0},
            name = "ortho_back",
            view_ratio = {
                x = 0.5, y = 0, w = 0.5, h = 0.5,
            },
        },
        left = {
            viewdir = {1, 0, 0, 0},
            name = "ortho_left",
            view_ratio = {
                x = 0, y = 0.5, w = 0.5, h = 0.5,
            },
        },
        right = {
            viewdir = {-1, 0, 0, 0},
            name = "ortho_right",
            view_ratio = {
                x = 0, y = 0.5, w = 0.5, h = 0.5,
            },
        },
        top = {
            viewdir = {0, -1, 0, 0},
            name = "ortho_top",
            view_ratio = {
                x = 0.5, y = 0.5, w = 0.5, h = 0.5,
            },
        },
        bottom = {
            viewdir = {0, 1, 0, 0},
            name = "ortho_bottom",
            view_ratio = {
                x = 0.5, y = 0.5, w = 0.5, h = 0.5,
            },
        },
    }

    for k, v in pairs(orthoview) do
        orthoview[k].eid = irender.create_orthoview_queue(rect_from_ratio(mainqueue_rect, v.view_ratio), v.name)
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
        iom.set_direction(world[eid].camera_eid, v.viewdir)
    end
end

local function hide_ortho_view()
    for _, n in ipairs(viewqueue[viewidx]) do
        local eid = orthoview[n].eid
        irenderqueue.set_visible(eid, false)
    end
end

function svs:data_changed()
    for _, key, press, state in kb_mb:unpack() do
        if key == "H" and press == 0 then
            hide_ortho_view()
            viewidx = viewidx == 2 and 1 or 2
            show_ortho_view()
        end
		if key == "G" and press == 0 then
            splitview = not splitview
            
            if splitview then
                backup_mainqueue_rect()
                show_ortho_view()
            else
                recover_mainqueue_rect()
                hide_ortho_view()
            end
		end
	end
end

function svs:update_camera()
    for _, eid in world:each "orthoview" do
        local rc = world[world[eid].camera_eid]._rendercache
        local worldmat = rc.worldmat
        rc.viewmat = math3d.lookto(math3d.index(worldmat, 4), math3d.index(worldmat, 3), rc.updir)
        rc.projmat = math3d.projmat(rc.frustum)
        rc.viewprojmat = math3d.mul(rc.projmat, rc.viewmat)
    end
end
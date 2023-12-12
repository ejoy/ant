local ecs = ...
local world = ecs.world
local w = world.w
local math3d    = require "math3d"

local icamera   = ecs.require "ant.camera|camera"
local irender   = ecs.require "ant.render|render_system.render"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local irq       = ecs.require "ant.render|render_system.renderqueue"

local hwi       = import_package "ant.hwi"

local INV_Z<const> = true
local INF_F<const> = true
local svs = ecs.system "splitviews_system"

local orthoview
local mainqueue_rect = {}
local function copy_rect(rt, dst_rt)
    for k, v in pairs(rt) do dst_rt[k] = v end
end
local function backup_mainqueue_rect()
    for e in w:select "main_queue camera_ref:in render_target:in" do
        copy_rect(e.render_target.view_rect, mainqueue_rect)
    end
end

local function recover_mainqueue_rect()
    for e in w:select "main_queue camera_ref:in" do
        mainqueue_rect(mainqueue_rect, e.render_target.view_rect)
    end
end

local function rect_from_ratio(rc, ratio)
    return {
        x = math.floor(rc.x + ratio.x * rc.w),
        y = math.floor(rc.y + ratio.y * rc.h),
        w = math.max(1, math.floor(rc.w * ratio.w)),
        h = math.max(1, math.floor(rc.h * ratio.h)),
    }
end

function svs:init()
    orthoview = {
        front = {
            camera_ref = icamera.create{
                viewdir = {0, 0, 1, 0},
                updir   = {0, 1, 0, 0},
                eyepos  = {0, 0, -5, 0},
                ortho   = true,
            },
            name = "ortho_front_queue",
            view_ratio = {
                x = 0.5, y = 0, w = 0.5, h = 0.5,
            },
        },
        back = {
            camera_ref = icamera.create{
                viewdir = {0, 0, -1, 0},
                updir   = {0, 1, 0, 0},
                eyepos  = {0, 0, 5, 0},
                ortho   = true,
            },
            name = "ortho_back_queue",
            view_ratio = {
                x = 0.5, y = 0, w = 0.5, h = 0.5,
            },
        },
        left = {
            camera_ref = icamera.create{
                viewdir = {1, 0, 0, 0},
                updir   = {0, 1, 0, 0},
                eyepos  = {-5, 0, 0, 0},
                ortho   = true,
            },
            name = "ortho_left_queue",
            view_ratio = {
                x = 0, y = 0.5, w = 0.5, h = 0.5,
            },
        },
        right = {
            camera_ref = icamera.create{
                viewdir = {-1, 0, 0, 0},
                updir   = {0, 1, 0, 0},
                eyepos  = {5, 0, 0, 0},
                ortho   = true,
            },
            name = "ortho_right_queue",
            view_ratio = {
                x = 0, y = 0.5, w = 0.5, h = 0.5,
            },
        },
        top = {
            camera_ref = icamera.create{
                viewdir = {0, -1, 0, 0},
                updir   = {0, 0, 1, 0},
                eyepos  = {0, 5, 0, 0},
                ortho   = true,
            },
            name = "ortho_top_queue",
            view_ratio = {
                x = 0.5, y = 0.5, w = 0.5, h = 0.5,
            },
        },
        bottom = {
            camera_ref = icamera.create{
            viewdir = {0, 1, 0, 0},
            updir   = {0, 0, -1, 0},
            eyepos  = {0, -5, 0, 0},
            ortho   = true,
            },
            name = "ortho_bottom_queue",
            view_ratio = {
                x = 0.5, y = 0.5, w = 0.5, h = 0.5,
            },
        },
    }

    local lastname = "main_view"
    for k, v in pairs(orthoview) do
        hwi.viewid_generate(v.name, lastname)
        irender.create_view_queue({x=0, y=0, w=1, h=1}, v.name, v.camera_ref)
        lastname = v.name
    end
end

function svs:entity_init()
    for e in w:select "INIT main_queue camera_ref:in render_target:in" do
        local vr = e.render_target.view_rect
        copy_rect(vr, mainqueue_rect)
        for k, v in pairs(orthoview) do
            irq.set_view_rect(v.name, rect_from_ratio(vr, v.view_ratio))
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
    irq.set_view_rect("main_queue", {x=mainqueue_rect.x, y=mainqueue_rect.y, w=mainqueue_rect.w*0.5, h=mainqueue_rect.h*0.5})

    for _, n in ipairs(viewqueue[viewidx]) do
        local v = orthoview[n]
        irq.set_view_rect(v.name, rect_from_ratio(mainqueue_rect, v.view_ratio))
        irq.set_visible(v.name, true)
    end
end

local function hide_ortho_view()
    irq.set_view_rect("main_queue", mainqueue_rect)
    for _, v in pairs(orthoview) do
        irq.set_visible(v.name, false)
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
        for _, _, camera_refs in svcc_mb:unpack() do
            local vq = viewqueue[viewidx]
            for idx, n in ipairs(vq) do
                irq.set_camera_from_queuename(orthoview[n].name, camera_refs[idx])
            end
        end
    end
end

function svs:update_camera()
    for k, v in pairs(orthoview) do
        local qn = v.name
        local qe = w:first(qn .. " camera_ref:in")
        local ceid = qe.camera_ref
        local cref <close> = world:entity(ceid, "scene_changed?in camera:update scene:in")
        if cref.scene_changed then
            local camera = cref.camera
            local scene = cref.scene
            local worldmat = scene.worldmat
            local d, p = math3d.index(worldmat, 3, 4)
            camera.viewmat.m = math3d.lookto(p, d, scene.updir)
            camera.projmat.m = math3d.projmat(camera.frustum, INV_Z)
            camera.infprojmat.m  = math3d.projmat(camera.frustum, INV_Z, INF_F)
            camera.viewprojmat.m = math3d.mul(camera.projmat, camera.viewmat)
        end
    end
end
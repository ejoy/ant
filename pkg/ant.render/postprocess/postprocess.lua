local ecs       = ...
local world     = ecs.world
local w         = world.w
local fbmgr     = require "framebuffer_mgr"
local math3d    = require "math3d"

local imaterial = ecs.require "ant.asset|material"
local util      = ecs.require "postprocess.util"
local pp_sys    = ecs.system "postprocess_system"

local mq_camera_mb = world:sub{"main_queue", "camera_changed"}

function pp_sys:init()
    world:create_entity {
        policy = {
            "ant.render|postprocess_object",
        },
        data = {
            postprocess = true,
            postprocess_input = {},
        }
    }
end

local need_update_scene_buffers

local need_update_pp_param
local function update_postprocess_param()
    for _, _, ceid in mq_camera_mb:unpack() do
        need_update_pp_param = ceid
    end

    if not need_update_pp_param then
        local mq = w:first "main_queue camera_ref:in"
        local ce = world:entity(mq.camera_ref, "camera_changed?in")
        if ce.camera_changed then
            need_update_pp_param = mq.camera_ref
        end
    end

    if need_update_pp_param then
        local ce = world:entity(need_update_pp_param, "camera:in")
        local projmat = ce.camera.projmat
        local X, Y, A, B = util.reverse_position_param(projmat)
        imaterial.system_attrib_update("u_reverse_pos_param", math3d.vector(X, Y, A, B))
        need_update_pp_param = nil
    end
end



function pp_sys:init_world()
    local mq = w:first("main_queue camera_ref:in")
    need_update_pp_param = mq.camera_ref
    need_update_scene_buffers = true
end

local viewrect_changed = world:sub{"view_rect_changed", "main_queue"}

local function update_postprocess_input()
    for _ in viewrect_changed:each() do
        need_update_scene_buffers = true
    end

    if need_update_scene_buffers then
        local pp = w:first "postprocess postprocess_input:in"
        local ppi = pp.postprocess_input
    
        local mq = w:first "main_queue render_target:in camera_ref:in"
        local fb = fbmgr.get(mq.render_target.fb_idx)
    
        ppi.scene_color_handle = fbmgr.get_rb(fb[1].rbidx).handle
        ppi.scene_depth_handle = fbmgr.get_rb(fb[#fb].rbidx).handle
        need_update_scene_buffers = nil
    end
end

function pp_sys:pre_postprocess()
    update_postprocess_param()
    update_postprocess_input()
end
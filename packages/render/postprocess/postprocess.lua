local ecs       = ...
local world     = ecs.world
local w         = world.w
local fbmgr     = require "framebuffer_mgr"

local pp_sys    = ecs.system "postprocess_system"

function pp_sys:init()
    ecs.create_entity {
        policy = {
            "ant.render|postprocess_object",
            "ant.general|name",
        },
        data = {
            postprocess = true,
            postprocess_input = {},
            name = "postprocess_obj",
        }
    }
end

function pp_sys:pre_postprocess()
    --TODO: check screen buffer changed
    local pp = w:singleton("postprocess", "postprocess_input:in")
    local ppi = pp.postprocess_input
    local mq = w:singleton("main_queue", "render_target:in")
    local fb = fbmgr.get(mq.render_target.fb_idx)

    ppi.scene_color_handle = fbmgr.get_rb(fb[1].rbidx).handle
    ppi.scene_depth_handle = fbmgr.get_rb(fb[#fb].rbidx).handle
end
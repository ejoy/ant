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
            postprocess_input = {
                {}, --at least one input, first init from pre_postprocess
            },
            name = "postprocess_obj",
        }
    }
end

function pp_sys:pre_postprocess()
    --TODO: check screen buffer changed
    local pp = w:singleton("postprocess", "postprocess_input:in")
    local mq = w:singleton("main_queue", "render_target:in")
    local fb = fbmgr.get(mq.render_target.fb_idx)
    for i=1, #fb do
        pp.postprocess_input[i].handle = fbmgr.get_rb(fb[i]).handle
    end
end
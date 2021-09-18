local ecs       = ...
local world     = ecs.world
local w         = world.w
local fbmgr     = require "framebuffer_mgr"
local viewidmgr = require "viewid_mgr"

local pp_sys    = ecs.system "postprocess_system"

local function local_postprocess_views(num)
    local viewids = {}
    local name = "postprocess"
    for i=1, num do
        viewids[#viewids+1] = viewidmgr.get(name .. i)
    end
    return viewids
end

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
    pp.postprocess_input[1].handle = fbmgr.get_rb(fbmgr.get(mq.render_target.fb_idx)[1]).handle
end

-- local ipp = ecs.interface "postprocess"

-- function ipp.main_rb_size(main_fbidx)
--     if main_fbidx == nil then
--         for e in w:select "main_queue render_target:in" do
--             main_fbidx = e.render_target.fb_idx
--             break
--         end
--     end

--     local fb = fbmgr.get(main_fbidx)
--     local rb = fbmgr.get_rb(fb[1])
    
--     assert(rb.format:match "RGBA")
--     return rb.w, rb.h
-- end

-- function ipp.get_rbhandle(fbidx, rbidx)
--     local fb = fbmgr.get(fbidx)
--     return fbmgr.get_rb(fb[rbidx]).handle
-- end
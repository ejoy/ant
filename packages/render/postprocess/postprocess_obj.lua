local ecs   = ...
local world = ecs.world
local w     = world.w

local viewidmgr     = require "viewid_mgr"
local fbmgr         = require "framebuffer_mgr"

local ppobj_viewid<const>  = viewidmgr.get "postprocess_obj"
local irq           = ecs.import.interface "ant.render|irenderqueue"

local pp_obj_sys = ecs.system "postprocess_obj_system"

local function deep_copy(src, dst)
    for k, v in pairs(src) do
        local t = type(v)
        if t == "table" then
            dst[k] = {}
            deep_copy(v, dst[k])
        else
            assert(t ~= "function")
            dst[k] = v
        end
    end
end

local copy_rendertarget = deep_copy

function pp_obj_sys:init_world()
    for mq in w:select "main_queue camera_ref:in render_target:in" do
        local mq_rt = mq.render_target
        local rt = {}
        copy_rendertarget(mq_rt, rt)
        rt.viewid = ppobj_viewid
        rt.clear_state.clear = ""
        ecs.create_entity{
            policy = {
                "ant.general|name",
                "ant.render|render_queue",
                "ant.render|watch_screen_buffer",
                "ant.render|cull",
            },
            data = {
                camera_ref      = mq.camera_ref,
                render_target   = rt,
                primitive_filter = {
                    filter_type = "postprocess_obj",
                    "opacity",
                    "translucent",
                },
                name = "postprocess_obj_queue",
                postprocess_obj_queue = true,
                queue_name = "postprocess_obj_queue",
                watch_screen_buffer = true,
                visible = true,
            },
        }
    end
end

local mb_camera_changed = world:sub{"main_queue", "camera_changed"}

function pp_obj_sys:data_changed()
    for _ in mb_camera_changed:each() do
        local mq = w:first("main_queue camera_ref:in")
        irq.set_camera("postprocess_obj_queue", mq.camera_ref)
    end
end
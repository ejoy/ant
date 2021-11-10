local ecs   = ...
local world = ecs.world
local w     = world.w

local viewidmgr = require "viewid_mgr"

local ppobj_viewid = viewidmgr.get "postprocess_obj"
local ies = ecs.import.interface "ant.scene|ientity_state"

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
                cull_tag    = {},
                name = "postprocess_obj_queue",
                postprocess_obj_queue = true,
                queue_name = "postprocess_obj_queue",
                watch_screen_buffer = true,
                visible = true,
                shadow_render_queue = {},
            },
        }
    end

    for e in w:select "render_object:in" do
        if ies.has_state(e, "postprocess_obj") then
            e.render_object_update = true
            w:sync("render_object_update:out", e)
        end
    end

end
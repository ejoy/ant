local ecs = ...
local world = ecs.world
local w = world.w

local setting   = import_package "ant.settings".setting

local ENABLE_FXAA<const> = setting:get "graphic/postprocess/fxaa/enable"

local ivs           = ecs.import.interface "ant.scene|ivisible_state"
local sd_sys        = ecs.system "scene_depth_system"
local rendercore    = ecs.clibs "render.core"
local queuemgr      = require "queue_mgr"

if not ENABLE_FXAA then
    local function DEF_FUNC() end
    sd_sys.post_init = DEF_FUNC
end

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"

local irq       = ecs.import.interface "ant.render|irenderqueue"

function sd_sys:post_init()
    local vr = world.args.viewport
    ecs.create_entity {
        policy = {
            "ant.render|scene_depth_queue",
            "ant.general|name",
        },
        data = {
            camera_ref = 0,
            render_target = {
                view_rect = mu.copy_viewrect(vr),
                viewid = viewidmgr.get "scene_depth",
                fb_idx = fbmgr.create{
                    rbidx = fbmgr.create_rb{
                        format = "D16F", layers = 1,
                        w = vr.w, h = vr.h,
                        flags = sampler{
                            RT="RT_ON",
                            U = "CLAMP",
                            V = "CLAMP",
                            MIN = "LINEAR",
                            MAG = "LINEAR",
                        },
                    }
                },
                clear_state = {
                    clear = "D",
                    depth = 0.0,
                },
            },
            queue_name = "scene_depth_queue",
            name = "scene_depth_queue",
            visible = false,
            scene_depth_queue = true,
            on_ready = function (e)
                local mq = w:first "main_queue camera_ref:in"
                irq.set_camera("scene_depth_queue", mq.camera_ref)
            end
        }
    }
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
local mc_mb = world:sub{"main_queue", "camera_changed"}

function sd_sys:data_changed()
    for _, _, vr in vr_mb:unpack() do
        irq.set_view_rect("scene_depth_queue", vr)
    end

    for _, _, ceid in mc_mb:unpack() do
        local e = w:first "scene_depth_queue camera_ref:out"
        e.camera_ref = ceid
        w:submit(e)
    end
end

function sd_sys:end_filter()
    assert(false, "filter_result is miss here, it have been clear in render_system.lua:end_filter")
    for e in w:select "filter_result visible_state:in opacity render_object:update filter_material:in" do
        if e.visible_state["pre_depth_queue"] then
            local fm = e.filter_material
            fm["scene_depth_queue"] = fm.pre_depth_queue
    
            rendercore.rm_set(e.render_object.rm_idx, queuemgr.material_index "scene_depth_queue", fm.pre_depth_queue:ptr())
            ivs.set_state(e, "scene_depth_queue", true)
        end
    end
end
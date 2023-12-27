local ecs = ...
local world = ecs.world
local w = world.w

local setting   = import_package "ant.settings"

local ENABLE_FXAA<const> = setting:get "graphic/postprocess/fxaa/enable"
local ENABLE_TAA<const> = setting:get "graphic/postprocess/taa/enable"

local ivs           = ecs.require "ant.render|visible_state"
local sd_sys        = ecs.system "scene_depth_system"
local R             = world:clibs "render.render_material"
local queuemgr      = ecs.require "queue_mgr"
local iviewport = ecs.require "ant.render|viewport.state"

if (not ENABLE_FXAA) and (not ENABLE_TAA) then
    local function DEF_FUNC() end
    sd_sys.post_init = DEF_FUNC
end

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local hwi       = import_package "ant.hwi"
local sampler   = import_package "ant.render.core".sampler
local fbmgr     = require "framebuffer_mgr"


local irq       = ecs.require "ant.render|render_system.renderqueue"

function sd_sys:post_init()
    local vr = iviewport.viewrect
    world:create_entity {
        policy = {
            "ant.render|scene_depth_queue",
        },
        data = {
            camera_ref = 0,
            render_target = {
                view_rect = mu.copy_viewrect(vr),
                viewid = hwi.viewid_get "scene_depth",
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
            visible = false,
            scene_depth_queue = true,
            on_ready = function (e)
                local mq = w:first "main_queue camera_ref:in"
                irq.set_camera_from_queuename("scene_depth_queue", mq.camera_ref)
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
    
            R.set(e.render_object.rm_idx, queuemgr.material_index "scene_depth_queue", fm.pre_depth_queue:ptr())
            ivs.set_state(e, "scene_depth_queue", true)
        end
    end
end
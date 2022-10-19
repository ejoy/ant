local ecs   = ...
local world = ecs.world
local w     = world.w
local mu = import_package "ant.math".util

local fbmgr     = require "framebuffer_mgr"
local viewidmgr = require "viewid_mgr"
local sampler   = require "sampler"

local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local ivs       = ecs.import.interface "ant.scene|ivisible_state"
local bgfx      = require "bgfx"


local sd_sys = ecs.system "scene_depth_system"

function sd_sys.post_init()
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
                        flags = sampler{RT="RT_ON",},
                    }
                },
                clear_state = {
                    clear = "D",
                    depth = 0.0,
                },
                view_mode = "s",
            },
            primitive_filter = {
                filter_type = "main_view",
                "opacity",
            },
            queue_name = "scene_depth_queue",
            name = "scene_depth_queue",
            visible = false,
            scene_depth_queue = true,
            on_ready = function (e)
                local pd = w:first("pre_depth_queue camera_ref:in")
                irq.set_camera("scene_depth_queue", pd.camera_ref)
            end
        }
    }
end


local pre_depth_material
local pre_depth_skinning_material

local function which_material(skinning)
	local res = skinning and pre_depth_skinning_material or pre_depth_material
    return res.object
end


local s = ecs.system "pre_depth_system"

function s:init()
    if not irender.use_pre_depth() then
        return
    end

    pre_depth_material 			= imaterial.load_res "/pkg/ant.resources/materials/predepth.material"
    pre_depth_skinning_material = imaterial.load_res "/pkg/ant.resources/materials/predepth_skin.material"
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
local mc_mb = world:sub{"main_queue", "camera_changed"}
function s:data_changed()
    if irender.use_pre_depth() then
        for msg in vr_mb:each() do
            local vr = msg[3]
            local dq = w:first("pre_depth_queue render_target:in")
            local dqvr = dq.render_target.view_rect
            --have been changed in viewport detect
            assert(vr.w == dqvr.w and vr.h == dqvr.h)
            if vr.x ~= dqvr.x or vr.y ~= dqvr.y then
                irq.set_view_rect("pre_depth_queue", vr)
                irq.set_view_rect("scene_depth_queue", vr)
            end
        end

        for _, _, ceid in mc_mb:unpack() do
            local e = w:first("pre_depth_queue", "camera_ref:out")
            e.camera_ref = ceid
            w:submit(e)

            e = w:first("scene_depth_queue", "camera_ref:out")
            e.camera_ref = ceid
            w:submit(e)
        end
    end
end

local material_cache = {__mode="k"}

function s:end_filter()
    if irender.use_pre_depth() then
        for e in w:select "filter_result pre_depth_queue_visible opacity render_object:update filter_material:in skinning?in scene_depth_queue_visible?out" do
            local mo = assert(which_material(e.skinning))
            local ro = e.render_object
            local fm = e.filter_material
            
            local newstate = irender.check_set_state(mo, fm.main_queue:get_material())
            local new_mo = irender.create_material_from_template(mo, newstate, material_cache)

            local mi = new_mo:instance()

            local h = mi:ptr()
            fm["pre_depth_queue"] = mi
            ro.mat_predepth = h

            fm["scene_depth_queue"] = mi
            ro.mat_scenedepth = h

            e["scene_depth_queue_visible"] = true
        end
    end
end

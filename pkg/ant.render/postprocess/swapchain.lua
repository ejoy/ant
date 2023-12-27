local ecs   = ...
local world = ecs.world
local w     = world.w

local setting = import_package "ant.settings"
local ENABLE_FXAA<const>    = setting:get "graphic/postprocess/fxaa/enable"
local ENABLE_TAA   <const>  = setting:get "graphic/postprocess/taa/enable"
local sc_sys = ecs.system "swapchain_system"

local hwi           = import_package "ant.hwi"

local mu            = import_package "ant.math".util
local fbmgr         = require "framebuffer_mgr"

local util          = ecs.require "postprocess.util"

local imaterial     = ecs.require "ant.asset|material"
local irender       = ecs.require "ant.render|render_system.render"
local irq           = ecs.require "ant.render|render_system.renderqueue"
local ifsr          = ecs.require "ant.render|postprocess.fsr"
local iviewport     = ecs.require "ant.render|viewport.state"

local scene_ratio   = irender.get_framebuffer_ratio("scene_ratio")
local NEED_UPSACLE <const>   = scene_ratio >= 0.5 and scene_ratio < 1
local ENABLE_FSR   <const>   = setting:get "graphic/postprocess/fsr/enable" and (ENABLE_FXAA or ENABLE_TAA) and NEED_UPSACLE
--local ENABLE_FSR   <const>   = nil
function sc_sys:init()
    world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            simplemesh       = irender.full_quad(),
            material         = "/pkg/ant.resources/materials/postprocess/swapchain.material",
            visible_state    = "swapchain_queue",
            swapchain_drawer = true,
            scene            = {},
        }
    }
end

local swapchain_viewid<const> = hwi.viewid_get "swapchain"

function sc_sys:init_world()
    util.create_queue(swapchain_viewid, mu.copy_viewrect(iviewport.device_size), nil, "swapchain_queue", "swapchain_queue")
end

local scene_viewrect_changed_mb = world:sub{"scene_viewrect_changed"}

function sc_sys:data_changed()
    for _, vr in scene_viewrect_changed_mb:unpack() do
        irq.set_view_rect("swapchain_queue", iviewport.device_size)
        break
    end
end

function sc_sys:swapchain()

    local function get_scene_handle()
        local se = w:first "stop_scene"
        if se then
            local be = w:first "blur pyramid_sample:in"
            return be.pyramid_sample.scene_color_property.value
        else
            if not ENABLE_FXAA then
                local tqe = w:first "tonemapping_queue render_target:in"
                return fbmgr.get_rb(tqe.render_target.fb_idx, 1).handle
            elseif not ENABLE_FSR then
                local fqe = w:first "fxaa_queue render_target:in"
                return fbmgr.get_rb(fqe.render_target.fb_idx, 1).handle
            else
                return ifsr.get_fsr_output_handle()
            end
        end
    end

    local fd = w:first "swapchain_drawer filter_material:in"
    imaterial.set_property(fd, "s_scene_color", get_scene_handle())

end


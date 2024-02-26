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
local queuemgr      = ecs.require "queue_mgr"
local imaterial     = ecs.require "ant.asset|material"
local irender       = ecs.require "ant.render|render"
local irq           = ecs.require "ant.render|render_system.renderqueue"
local ifsr          = ecs.require "ant.render|postprocess.fsr"
local iviewport     = ecs.require "ant.render|viewport.state"

local ENABLE_FSR   <const>   = setting:get "graphic/postprocess/fsr/enable" and (ENABLE_FXAA or ENABLE_TAA)

local swapchain_viewid<const> = hwi.viewid_get "swapchain"
local RENDER_ARG
local swapchain_drawereid

local function register_queue()
    queuemgr.register_queue "swapchain_queue"
    RENDER_ARG = irender.pack_render_arg("swapchain_queue", swapchain_viewid)

    util.create_queue(swapchain_viewid, mu.copy_viewrect(iviewport.device_viewrect), nil, "swapchain_queue", "swapchain_queue")
end

function sc_sys:init()
    register_queue()
    swapchain_drawereid = world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            simplemesh       = irender.full_quad(),
            material         = "/pkg/ant.resources/materials/postprocess/swapchain.material",
            visible_state    = "swapchain_queue",
            scene            = {},
        }
    }
end

local device_viewrect_changed_mb = world:sub{"device_viewrect_changed"}

function sc_sys:data_changed()
    for _, _ in device_viewrect_changed_mb:unpack() do
        irq.set_view_rect("swapchain_queue", iviewport.device_viewrect)
        break
    end
end

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
function sc_sys:swapchain()
    local fd = world:entity(swapchain_drawereid, "filter_material:in")
    imaterial.set_property(fd, "s_scene_color", get_scene_handle())
end

function sc_sys:render_submit()
    irender.draw(RENDER_ARG, swapchain_drawereid)
end


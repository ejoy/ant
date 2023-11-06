local ecs   = ...
local world = ecs.world
local w     = world.w

local setting = import_package "ant.settings"
local ENABLE_FXAA<const>    = setting:get "graphic/postprocess/fxaa/enable"
local sc_sys = ecs.system "swapchain_system"

local hwi       = import_package "ant.hwi"

local mu        = import_package "ant.math".util
local fbmgr     = require "framebuffer_mgr"

local util      = ecs.require "postprocess.util"

local imaterial = ecs.require "ant.asset|material"
local irender   = ecs.require "ant.render|render_system.render"
local irq       = ecs.require "ant.render|render_system.renderqueue"

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
    util.create_queue(swapchain_viewid, mu.copy_viewrect(world.args.viewport), nil, "swapchain_queue", "swapchain_queue")
end

local vp_changed_mb = world:sub{"world_viewport_changed"}

function sc_sys:data_changed()
    for _, vp in vp_changed_mb:unpack() do
        irq.set_view_rect("swapchain_queue", vp)
        break
    end
end

function sc_sys:swapchain()
    local sceneldr_handle
    if not ENABLE_FXAA then
        local tqe = w:first "tonemapping_queue render_target:in"
        sceneldr_handle = fbmgr.get_rb(tqe.render_target.fb_idx, 1).handle
    else
        local fqe = w:first "fxaa_queue render_target:in"
        sceneldr_handle = fbmgr.get_rb(fqe.render_target.fb_idx, 1).handle
    end

    local fd = w:first "swapchain_drawer filter_material:in"
    local se = w:first "stop_scene"
    if se then
        local be = w:first "blur pyramid_sample:in"
        imaterial.set_property(fd, "s_scene_color", be.pyramid_sample.scene_color_property.value)
    else
        imaterial.set_property(fd, "s_scene_color", sceneldr_handle)
    end
end


local ecs   = ...
local world = ecs.world
local w     = world.w

local setting = import_package "ant.settings"
local ENABLE_FXAA<const>    = setting:get "graphic/postprocess/fxaa/enable"
local fxaasys = ecs.system "fxaa_system"
if not ENABLE_FXAA then
    return
end

local sampler   = import_package "ant.render.core".sampler
local ENABLE_TAA<const>    = setting:get "graphic/postprocess/taa/enable"

local hwi       = import_package "ant.hwi"

local mu        = import_package "ant.math".util
local fbmgr     = require "framebuffer_mgr"

local util      = ecs.require "postprocess.util"

local imaterial = ecs.require "ant.asset|material"
local irender   = ecs.require "ant.render|render_system.render"
local irq       = ecs.require "ant.render|render_system.renderqueue"
local iviewport = ecs.require "ant.render|viewport.state"

function fxaasys:init()
    world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            simplemesh      = irender.full_quad(),
            material        = "/pkg/ant.resources/materials/postprocess/fxaa.material",
            visible_state   = "fxaa_queue",
            fxaa_drawer     = true,
            scene           = {},
        }
    }
end

local function create_fb(vr)
    local minmag_flag<const> = ENABLE_TAA and "POINT" or "LINEAR"
    return fbmgr.create{
        rbidx = fbmgr.create_rb{
            w = vr.w, h = vr.h, layers = 1,
            format = "RGBA8",
            flags = sampler{
                U = "CLAMP",
                V = "CLAMP",
                MIN=minmag_flag,
                MAG=minmag_flag,
                RT="RT_ON",
                BLIT="BLIT_COMPUTEWRITE"
            },
        }
    }
end

local fxaa_viewid<const> = hwi.viewid_get "fxaa"

function fxaasys:init_world()
    local vr = mu.copy_viewrect(iviewport.viewrect)
    util.create_queue(fxaa_viewid, mu.copy_viewrect(iviewport.viewrect), create_fb(vr), "fxaa_queue", "fxaa_queue", true)
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}

function fxaasys:data_changed()
    for _, _, vr in vr_mb:unpack() do
        irq.set_view_rect("fxaa_queue", vr)
        break
    end
end

function fxaasys:fxaa()

    local function get_scene_ldr_handle()
        if not ENABLE_TAA then
            local tme = w:first "tonemapping_queue render_target:in"
            return fbmgr.get_rb(tme.render_target.fb_idx, 1).handle
        else
            local tame = w:first "taa_queue render_target:in"
            return fbmgr.get_rb(tame.render_target.fb_idx, 1).handle
        end
    end

    local fd = w:first "fxaa_drawer filter_material:in"
    imaterial.set_property(fd, "s_scene_ldr_color", get_scene_ldr_handle())
end


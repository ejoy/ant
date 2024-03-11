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

local imaterial = ecs.require "ant.render|material"
local irender   = ecs.require "ant.render|render"
local irq       = ecs.require "ant.render|renderqueue"
local iviewport = ecs.require "ant.render|viewport.state"
local queuemgr  = ecs.require "queue_mgr"

local fxaa_viewid<const> = hwi.viewid_get "fxaa"

local RENDER_ARG
local fxaadrawer_eid
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

local function register_queue()
    queuemgr.register_queue "fxaa_queue"
    RENDER_ARG = irender.pack_render_arg("fxaa_queue", fxaa_viewid)

    local vr = mu.copy_viewrect(iviewport.viewrect)
    util.create_queue(fxaa_viewid, mu.copy_viewrect(iviewport.viewrect), create_fb(vr), "fxaa_queue", "fxaa_queue", true)
end

function fxaasys:init()
    register_queue()
    fxaadrawer_eid = world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            mesh_result     = irender.full_quad(),
            material        = "/pkg/ant.resources/materials/postprocess/fxaa.material",
            visible_state   = "",
            scene           = {},
        }
    }
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}

local get_scene_ldr_handle; do
    local qn = ENABLE_TAA and "taa_queue render_target:in" or "tonemapping_queue render_target:in"
    function get_scene_ldr_handle()
        local q = w:first(qn)
        return fbmgr.get_rb(q.render_target.fb_idx, 1).handle
    end
end

local function update_scene_ldr()
    local fd = world:entity(fxaadrawer_eid, "filter_material:in")
    imaterial.set_property(fd, "s_scene_ldr_color", get_scene_ldr_handle())
end

function fxaasys:fxaa()
    for _, _, vr in vr_mb:unpack() do
        irq.set_view_rect("fxaa_queue", vr)
        update_scene_ldr()
        break
    end
end

function fxaasys:render_submit()
    irender.draw(RENDER_ARG, fxaadrawer_eid)
end

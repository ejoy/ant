local ecs   = ...
local world = ecs.world
local w     = world.w

local hwi       = import_package "ant.hwi"

local tm_sys    = ecs.system "tonemapping_system"
local irender   = ecs.require "ant.render|render"
local irq       = ecs.require "ant.render|renderqueue"

local util      = ecs.require "postprocess.util"
local mu        = import_package "ant.math".util
local fbmgr     = require "framebuffer_mgr"
local sampler   = import_package "ant.render.core".sampler
local setting   = import_package "ant.settings"
local iviewport = ecs.require "ant.render|viewport.state"
local ENABLE_BLOOM<const>   = setting:get "graphic/postprocess/bloom/enable"
local ENABLE_FXAA<const>    = setting:get "graphic/postprocess/fxaa/enable"
local ENABLE_TAA<const>     = setting:get "graphic/postprocess/taa/enable"
local ENABLE_TM_LUT<const>  = setting:get "graphic/postprocess/tonemapping/use_lut"
local ifg = ecs.require "ant.render|postprocess.postprocess"
local tm_viewid<const>      = hwi.viewid_get "tonemapping"
local queuemgr              = ecs.require "queue_mgr"

local RENDER_ARG
local tonemapping_drawer_eid

local function check_create_fb(vr)
    if ENABLE_TAA or ENABLE_FXAA then
        local minmag_flag<const> = ENABLE_TAA and "POINT" or "LINEAR"
        local fbidx = fbmgr.create{
            rbidx = fbmgr.create_rb{
                w = vr.w, h = vr.h, layers = 1,
                format = "RGBA8",
                flags = sampler{
                    U = "CLAMP",
                    V = "CLAMP",
                    MIN=minmag_flag,
                    MAG=minmag_flag,
                    RT="RT_ON",
                },
            }
        }
        local handle = fbmgr.get_rb(fbidx, 1).handle
        ifg.set_stage_output("tonemapping", handle)
        return fbidx
    end
end

local function register_queue()
    queuemgr.register_queue "tonemapping_queue"
    RENDER_ARG = irender.pack_render_arg("tonemapping_queue", tm_viewid)

    local vr = mu.copy_viewrect(iviewport.viewrect)
    local fbidx = check_create_fb(vr)
    util.create_queue(tm_viewid, vr, fbidx, "tonemapping_queue", "tonemapping_queue", ENABLE_FXAA or ENABLE_TAA)
end

function tm_sys:init()
    register_queue()
    local drawer_material = ENABLE_TM_LUT and "/pkg/ant.resources/materials/postprocess/tonemapping_lut.material" or "/pkg/ant.resources/materials/postprocess/tonemapping.material"
    tonemapping_drawer_eid = world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            mesh_result     = irender.full_quad(),
            material        = drawer_material,
            visible_state   = "",
            tonemapping_drawer=true,
            scene           = {},
        }
    }
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}

local function update_properties(material)
    --TODO: we need something call frame graph, frame graph need two stage: compile and run, with virtual resource
    -- in compile stage, determine which postprocess stage is needed, and connect those virtual resources
    -- render target here, is one of the virtual resource

    local current_input = ifg.get_stage_input("tonemapping")
    local last_output = ifg.get_stage_output(current_input[1])
    material.s_scene_color = last_output
    local bloomhandle = ifg.get_stage_output(current_input[2])
    if bloomhandle then
        assert(ENABLE_BLOOM)
        material.s_bloom_color = bloomhandle
    end
end

function tm_sys:tonemapping()
    for _, _, vr in vr_mb:unpack() do
        irq.set_view_rect("tonemapping_queue", vr)
        local q = w:first "tonemapping_queue render_target:in"
        local handle = fbmgr.get_rb(q.render_target.fb_idx, 1).handle
        ifg.set_stage_output("tonemapping", handle)
        break
    end

    local m = w:first "tonemapping_drawer filter_material:in"
    update_properties(m.filter_material.DEFAULT_MATERIAL)
end

function tm_sys:render_submit()
    irender.draw(RENDER_ARG, tonemapping_drawer_eid)
end
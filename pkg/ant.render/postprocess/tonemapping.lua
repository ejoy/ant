local ecs   = ...
local world = ecs.world
local w     = world.w

local hwi       = import_package "ant.hwi"

local tm_sys    = ecs.system "tonemapping_system"
local irender   = ecs.require "ant.render|render_system.render"
local irq       = ecs.require "ant.render|render_system.renderqueue"

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
local tm_viewid<const>      = hwi.viewid_get "tonemapping"

function tm_sys:init()
    local drawer_material = ENABLE_TM_LUT and "/pkg/ant.resources/materials/postprocess/tonemapping_lut.material" or "/pkg/ant.resources/materials/postprocess/tonemapping.material"
    world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            simplemesh      = irender.full_quad(),
            material        = drawer_material,
            visible_state   = "tonemapping_queue",
            tonemapping_drawer=true,
            scene           = {},
        }
    }
end

local function check_create_fb(vr)
    if ENABLE_TAA or ENABLE_FXAA then
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
                },
            }
        }
    end
end

function tm_sys:init_world()
    local vr = mu.copy_viewrect(iviewport.viewrect)
    util.create_queue(tm_viewid, vr, check_create_fb(vr), "tonemapping_queue", "tonemapping_queue", ENABLE_FXAA or ENABLE_TAA)
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}

function tm_sys:data_changed()
    for _, _, vr in vr_mb:unpack() do
        irq.set_view_rect("tonemapping_queue", vr)
        break
    end
end

local function update_properties(material)
    --TODO: we need something call frame graph, frame graph need two stage: compile and run, with virtual resource
    -- in compile stage, determine which postprocess stage is needed, and connect those virtual resources
    -- render target here, is one of the virtual resource
    local pp = w:first "postprocess postprocess_input:in"
    local ppi = pp.postprocess_input
    material.s_scene_color = assert(ppi.scene_color_handle)
    local bloomhandle = ppi.bloom_color_handle
    if bloomhandle then
        assert(ENABLE_BLOOM)
        material.s_bloom_color = ppi.bloom_color_handle
    end
end

function tm_sys:tonemapping()
    local m = w:first "tonemapping_drawer filter_material:in"
    update_properties(m.filter_material.main_queue)
end
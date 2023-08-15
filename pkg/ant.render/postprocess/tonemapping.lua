local ecs   = ...
local world = ecs.world
local w     = world.w

local hwi       = import_package "ant.hwi"

local tm_sys    = ecs.system "tonemapping_system"
local irender   = ecs.require "ant.render|render_system.render"
local irq       = ecs.require "ant.render|render_system.renderqueue"
local imaterial = ecs.require "ant.asset|material"

local util      = ecs.require "postprocess.util"

local mu        = import_package "ant.math".util

local fbmgr     = require "framebuffer_mgr"
local sampler   = import_package "ant.compile_resource".sampler
local bgfx      = require "bgfx"
local setting   = import_package "ant.settings".setting

local ENABLE_BLOOM<const>   = setting:get "graphic/postprocess/bloom/enable"
local ENABLE_FXAA<const>    = setting:get "graphic/postprocess/fxaa/enable"
local ENABLE_TAA<const>     = setting:get "graphic/postprocess/taa/enable"
local ENABLE_TM_LUT<const>  = setting:get "graphic/postprocess/tonemapping/use_lut"
local LUT_DIM<const>        = setting:get "graphic/postprocess/tonemapping/lut_dim"
local tm_viewid<const>      = hwi.viewid_get "tonemapping"

local colorgrading   = require "postprocess.colorgrading.color_grading"

function tm_sys:init()
    local drawer_material = ENABLE_TM_LUT and "/pkg/ant.resources/materials/postprocess/tonemapping_lut.material" or "/pkg/ant.resources/materials/postprocess/tonemapping.material"
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            name            = "tonemapping_drawer",
            simplemesh      = irender.full_quad(),
            material        = drawer_material,
            visible_state   = "tonemapping_queue",
            tonemapping_drawer=true,
            on_ready = function (e)
                if ENABLE_TM_LUT then
                    local r = colorgrading.bake(assert(LUT_DIM))
                    --TODO: format should be R10G10B10A2
                    local flags<const> = sampler{
                        U = "CLAMP",
                        V = "CLAMP",
                        W = "CLAMP",
                        MIN="LINEAR",
                        MAG="LINEAR",
                    }
                    local handle = bgfx.create_texture3d(LUT_DIM, LUT_DIM, LUT_DIM, false, "RGBA32F", flags, r)
                    imaterial.set_property(e, "s_colorgrading_lut", handle)
                end
            end,
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
    local vr = mu.copy_viewrect(world.args.viewport)
    util.create_queue(tm_viewid, vr, check_create_fb(vr), "tonemapping_queue", "tonemapping_queue", ENABLE_FXAA or ENABLE_TAA)
end

local vp_changed_mb = world:sub{"world_viewport_changed"}
function tm_sys:data_changed()
    if (not ENABLE_FXAA) and (not ENABLE_TAA) then
        for _, vp in vp_changed_mb:unpack() do
            irq.set_view_rect("tonemapping_queue", vp)
            break
        end
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
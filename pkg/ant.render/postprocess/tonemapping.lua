local ecs   = ...
local world = ecs.world
local w     = world.w

local viewidmgr = require "viewid_mgr"

local tm_sys    = ecs.system "tonemapping_system"
local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local util      = ecs.require "postprocess.util"

local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"
local bgfx      = require "bgfx"
local setting   = import_package "ant.settings".setting

local ENABLE_BLOOM<const>   = setting:get "graphic/postprocess/bloom/enable"
local ENABLE_FXAA<const>    = setting:get "graphic/postprocess/fxaa/enable"
local ENABLE_TAA<const>     = setting:get "graphic/postprocess/taa/enable"
local ENABLE_TM_LUT<const>  = setting:get "graphic/postprocess/tonemapping/use_lut"
local tm_viewid<const>      = viewidmgr.get "tonemapping"

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
            view_visible    = true,
            tonemapping_drawer=true,
            on_ready = function (e)
                if ENABLE_TM_LUT then
                    local cfg = {
                        w = 32, h = 32, d = 32, 
                    }
                    local cg = util.bake_color_grading(cfg)
                    local flags = sampler{
                        U = "CLAMP",
                        V = "CLAMP",
                        W = "CLAMP",
                        MIN="LINEAR",
                        MAG="LINEAR",
                    }
                    local handle = bgfx.create_texture3d(cfg.w, cfg.h, cfg.d, false, "R10G10B10A2", flags, cg)
                    imaterial.set_property(e, "s_colorgrading_lut", handle)
                end
            end,
            scene           = {},
        }
    }
end

function tm_sys:init_world()
    local vp = world.args.viewport
    local vr = {x=vp.x, y=vp.y, w=vp.w, h=vp.h}
    local tm_fbidx
    if ENABLE_TAA then
        tm_fbidx = fbmgr.create{
            rbidx = fbmgr.create_rb{
                w = vr.w, h = vr.h, layers = 1,
                format = "RGBA8",
                flags = sampler{
                    U = "CLAMP",
                    V = "CLAMP",
                    MIN="POINT",
                    MAG="POINT",
                    RT="RT_ON",
                },
            }
        }
    elseif ENABLE_FXAA then
        tm_fbidx = fbmgr.create{
            rbidx = fbmgr.create_rb{
                w = vr.w, h = vr.h, layers = 1,
                format = "RGBA8",
                flags = sampler{
                    U = "CLAMP",
                    V = "CLAMP",
                    MIN="LINEAR",
                    MAG="LINEAR",
                    RT="RT_ON",
                },
            }
        }
    end  
    util.create_queue(tm_viewid, vr, tm_fbidx, "tonemapping_queue", "tonemapping_queue", ENABLE_FXAA or ENABLE_TAA)
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
    local pp = w:first("postprocess postprocess_input:in")
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
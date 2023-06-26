local ecs   = ...
local world = ecs.world
local w     = world.w
local bgfx      = require "bgfx"
local setting = import_package "ant.settings".setting
local ENABLE_TAA<const> = setting:data().graphic.postprocess.taa.enable
local renderutil = require "util"
local taasys = ecs.system "taa_system"
local math3d	= require "math3d"
if not ENABLE_TAA then
    renderutil.default_system(taasys, "init", "init_world", "taa", "data_changed")
    return
end

local mu        = import_package "ant.math".util
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"
local viewidmgr = require "viewid_mgr"
local util      = ecs.require "postprocess.util"

local imaterial = ecs.import.interface "ant.asset|imaterial"
local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"

function taasys:init()
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            name            = "taa_drawer",
            simplemesh      = irender.full_quad(),
            material        = "/pkg/ant.resources/materials/postprocess/taa.material",
            visible_state   = "taa_queue",
            view_visible    = true,
            taa_drawer     = true,
            scene           = {},
        }
    }
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            name            = "taa_copy_drawer",
            simplemesh      = irender.full_quad(),
            material        = "/pkg/ant.resources/materials/postprocess/taa_copy.material",
            visible_state   = "taa_copy_queue",
            view_visible    = true,
            taa_copy_drawer     = true,
            scene           = {},
        }
    }
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            name            = "taa_present_drawer",
            simplemesh      = irender.full_quad(),
            material        = "/pkg/ant.resources/materials/postprocess/taa_copy.material",
            visible_state   = "taa_present_queue",
            view_visible    = true,
            taa_present_drawer     = true,
            scene           = {},
            
        }
    }

end


local taa_viewid<const> = viewidmgr.get "taa"
local taa_copy_viewid<const> = viewidmgr.get "taa_copy"
local taa_present_viewid<const> = viewidmgr.get "taa_present"

local tex_flags = sampler{
    U = "CLAMP",
    V = "CLAMP",
    MIN="LINEAR",
    MAG="LINEAR",
    BLIT="BLIT_AS_DST",
    COLOR_SPACE="sRGB",
}

function taasys:init_world()
    local vp = world.args.viewport
    local vr = {x=vp.x, y=vp.y, w=vp.w, h=vp.h}

    local taa_fbidx, taa_copy_fbidx
    taa_fbidx = fbmgr.create(
        {
        rbidx = fbmgr.create_rb{
            w = vr.w, h = vr.h, layers = 1,
            format = "RGBA8",
            flags = sampler{
                U = "CLAMP",
                V = "CLAMP",
                MIN="POINT",
                MAG="POINT",
                RT="RT_ON",
                COLOR_SPACE="sRGB",
                }
            },
        }
    ) 

    taa_copy_fbidx = fbmgr.create(
        {
        rbidx = fbmgr.create_rb{
            w = vr.w, h = vr.h, layers = 1,
            format = "RGBA8",
            flags = sampler{
                U = "CLAMP",
                V = "CLAMP",
                MIN="LINEAR",
                MAG="LINEAR",
                RT="RT_ON",
                COLOR_SPACE="sRGB",
                }
            },
        }
    ) 

    util.create_queue(taa_viewid, mu.copy_viewrect(world.args.viewport), taa_fbidx, "taa_queue", "taa_queue", true)
    util.create_queue(taa_copy_viewid, mu.copy_viewrect(world.args.viewport), taa_copy_fbidx, "taa_copy_queue", "taa_copy_queue", true)
    util.create_queue(taa_present_viewid, mu.copy_viewrect(world.args.viewport), nil, "taa_present_queue", "taa_present_queue", true)
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
function taasys:data_changed()
    for _, _, vr in vr_mb:unpack() do
        irq.set_view_rect("taa_queue", vr)
        irq.set_view_rect("taa_copy_queue", vr)
        irq.set_view_rect("taa_present_queue", vr)
        break
    end

end

function taasys:taa()
    local tm_qe = w:first "tonemapping_queue render_target:in"
    local taa_copy_qe = w:first "taa_copy_queue render_target:in"
    local v_qe = w:first "velocity_queue render_target:in"

    local sceneldr_handle = fbmgr.get_rb(tm_qe.render_target.fb_idx, 1).handle  
    local prev_sceneldr_handle = fbmgr.get_rb(taa_copy_qe.render_target.fb_idx, 1).handle
    local velocity_handle = fbmgr.get_rb(v_qe.render_target.fb_idx, 1).handle 

    local fd = w:first "taa_drawer filter_material:in"

    imaterial.set_property(fd, "s_prev_scene_ldr_color", prev_sceneldr_handle)
    imaterial.set_property(fd, "s_velocity", velocity_handle) 
    imaterial.set_property(fd, "s_scene_ldr_color", sceneldr_handle)
end

function taasys:taa_copy()
    local taa_qe = w:first "taa_queue render_target:in"

    local sceneldr_handle = fbmgr.get_rb(taa_qe.render_target.fb_idx, 1).handle  

    local fd = w:first "taa_copy_drawer filter_material:in"

    imaterial.set_property(fd, "s_scene_ldr_color", sceneldr_handle)
end

function taasys:taa_present()
    local taa_qe = w:first "taa_queue render_target:in"

    local sceneldr_handle = fbmgr.get_rb(taa_qe.render_target.fb_idx, 1).handle

    local fd = w:first "taa_present_drawer filter_material:in"

    imaterial.set_property(fd, "s_scene_ldr_color", sceneldr_handle)
end
local ecs   = ...
local world = ecs.world
local w     = world.w

local setting = import_package "ant.settings"
local ENABLE_TAA<const>    = setting:get "graphic/postprocess/taa/enable"
local taasys = ecs.system "taa_system"

if not ENABLE_TAA then
    return
end

local hwi       = import_package "ant.hwi"

local bgfx      = require "bgfx"
local ENABLE_FXAA<const>    = setting:get "graphic/postprocess/fxaa/enable"

local taa_present_viewid
if not ENABLE_FXAA then
    taa_present_viewid = hwi.viewid_get "taa_present"
end

local layoutmgr	= require "vertexlayout_mgr"
local mu        = import_package "ant.math".util
local sampler   = import_package "ant.render.core".sampler

local fbmgr     = require "framebuffer_mgr"
local util      = ecs.require "postprocess.util"

local imaterial = ecs.require "ant.render|material"
local irender   = ecs.require "ant.render|render"
local irq       = ecs.require "ant.render|renderqueue"
local iviewport = ecs.require "ant.render|viewport.state"

local taa_eid, taa_first_frame_eid
local taa_after_first_frame
function taasys:init()
    taa_eid = world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            mesh_result     = irender.full_quad(),
            material        = "/pkg/ant.resources/materials/postprocess/taa.material",
            visible_masks   = "",
            taa_drawer     = true,
            scene           = {},
        }
    } 
    local fullquad_vbhandle = bgfx.create_vertex_buffer(bgfx.memory_buffer("b", {1, 1, 1}), layoutmgr.get "p10NIu".handle)
    local fullquad<const> = {
        vb = {
            start = 0, num = 3,
            handle = fullquad_vbhandle,
        }
    }
    taa_first_frame_eid = world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            mesh_result     = fullquad,
            material        = "/pkg/ant.resources/materials/postprocess/taa_first_frame.material",
            visible_masks   = "",
            taa_first_frame_drawer     = true,
            scene           = {},
        }
    }
    world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            mesh_result     = irender.full_quad(),
            material        = "/pkg/ant.resources/materials/postprocess/taa_copy.material",
            visible_masks   = "",
            taa_copy_drawer = true,
            scene           = {},
        }
    }
    if not ENABLE_FXAA then
        world:create_entity{
            policy = {
                "ant.render|simplerender",
            },
            data = {
                mesh_result     = irender.full_quad(),
                material        = "/pkg/ant.resources/materials/postprocess/taa_copy.material",
                visible_masks   = "",
                taa_present_drawer = true,
                scene           = {},
            }
        } 
    end
end


local taa_viewid<const>      = hwi.viewid_get "taa"
local taa_copy_viewid<const> = hwi.viewid_get "taa_copy"


function taasys:init_world()
    local vp = iviewport.viewrect
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
                    }
                },
        }
    ) 

    util.create_queue(taa_viewid, mu.copy_viewrect(iviewport.viewrect), taa_fbidx, "taa_queue", "taa_queue", true)
    util.create_queue(taa_copy_viewid, mu.copy_viewrect(iviewport.viewrect), taa_copy_fbidx, "taa_copy_queue", "taa_copy_queue", true)
    if not ENABLE_FXAA then
        util.create_queue(taa_present_viewid, mu.copy_viewrect(iviewport.viewrect), nil, "taa_present_queue", "taa_present_queue", true) 
    end
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
function taasys:data_changed()
    for _, _, vr in vr_mb:unpack() do
        irq.set_view_rect("taa_queue", vr)
        irq.set_view_rect("taa_copy_queue", vr)
        if not ENABLE_FXAA then
            irq.set_view_rect("taa_present_queue", vr)
        end
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

    -- ffd exist frame0 frame1
    -- fd exist frame0 frame1 frame2 ...
    -- ffd draw before fd
    local ffd = w:first "taa_first_frame_drawer filter_material:in"
    local fd = w:first "taa_drawer filter_material:in"
    if ffd then
        imaterial.set_property(ffd, "s_scene_ldr_color", sceneldr_handle)
    end
    imaterial.set_property(fd, "s_scene_ldr_color", sceneldr_handle)
    imaterial.set_property(fd, "s_prev_scene_ldr_color", prev_sceneldr_handle)
    imaterial.set_property(fd, "s_velocity", velocity_handle)
end

function taasys:taa_copy()
    local mq = w:first "main_queue render_target:in camera_ref:in"
    local fb = fbmgr.get(mq.render_target.fb_idx)

    local taa_qe = w:first "taa_queue render_target:in"

    local sceneldr_handle = fbmgr.get_rb(taa_qe.render_target.fb_idx, 1).handle  

    local fc = w:first "taa_copy_drawer filter_material:in"
    imaterial.set_property(fc, "s_scene_ldr_color", sceneldr_handle)
end

function taasys:taa_present()
    if not ENABLE_FXAA then
        local taa_qe = w:first "taa_queue render_target:in"

        local sceneldr_handle = fbmgr.get_rb(taa_qe.render_target.fb_idx, 1).handle
    
        local fd = w:first "taa_present_drawer filter_material:in"
    
        imaterial.set_property(fd, "s_scene_ldr_color", sceneldr_handle) 
    end
end

function taasys:render_submit()
    irender.draw(RENDER_ARG, taa_first_frame_eid)
    irender.draw(RENDER_ARG, taa_eid)
end

function taasys:end_frame()
    if taa_first_frame_eid then
        if taa_after_first_frame then
            w:remove(taa_first_frame_eid)
            taa_first_frame_eid = nil
        else
            taa_after_first_frame = true 
        end
    end 
end

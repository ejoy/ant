local ecs   = ...
local world = ecs.world
local w     = world.w

local setting       = import_package "ant.settings"
local hwi           = import_package "ant.hwi"
local mu            = import_package "ant.math".util
local sampler       = import_package "ant.render.core".sampler
local renderpkg     = import_package "ant.render"
local fbmgr         = require "framebuffer_mgr"
local bgfx          = require "bgfx"
local math3d        = require "math3d"
local util          = ecs.require "postprocess.util"
local imaterial     = ecs.require "ant.asset|material"
local irender       = ecs.require "ant.render|render_system.render"
local irq           = ecs.require "ant.render|render_system.renderqueue"
local icompute      = ecs.require "ant.render|compute.compute"
local layoutmgr     = renderpkg.layoutmgr
local layout        = layoutmgr.get "p3|t20"
local scene_ratio   = irender.get_framebuffer_ratio("scene_ratio")
local ENABLE_FXAA  <const>   = setting:get "graphic/postprocess/fxaa/enable"
local ENABLE_TAA   <const>   = setting:get "graphic/postprocess/taa/enable"
local NEED_UPSACLE <const>   = scene_ratio >= 0.5 and scene_ratio < 1
local ENABLE_FSR   <const>   = setting:get "graphic/postprocess/fsr/enable" and (ENABLE_FXAA or ENABLE_TAA) and NEED_UPSACLE
--local ENABLE_FSR   <const>   = nil
local DEFAULT_DISPATCH_GROUP_SIZE_X<const>, DEFAULT_DISPATCH_GROUP_SIZE_Y<const> = 16, 16

if not ENABLE_FSR then
    return
end

local fsr_sys = ecs.system "fsr_system"

local flags<const> = sampler {
    MIN     =   "LINEAR",
    MAG     =   "LINEAR",
    U       =   "CLAMP",
    V       =   "CLAMP",
    RT      =   "RT_ON",
    BLIT    =   "BLIT_COMPUTEWRITE",
}

local rcasAttenuation = setting:get "graphic/postprocess/fsr/rcasAttenuation" or 0.2
local fsr_textures = {}
local fsr_params = {}
local fsr_dispatch_size = {}
local fsr_resolve_viewid<const> = hwi.viewid_get "fsr_resolve"
local fsr_easu_viewid<const>    = hwi.viewid_get "fsr_easu"
local fsr_rcas_viewid<const>    = hwi.viewid_get "fsr_rcas"
local ifsr = {}

function ifsr.get_fsr_output_handle()
    return fsr_textures.rcas_handle
end

local function set_fsr_disptach_size(vp)
    fsr_dispatch_size = {
        math.floor((vp.w + DEFAULT_DISPATCH_GROUP_SIZE_X - 1) / DEFAULT_DISPATCH_GROUP_SIZE_X),
        math.floor((vp.h + DEFAULT_DISPATCH_GROUP_SIZE_Y - 1) / DEFAULT_DISPATCH_GROUP_SIZE_Y),
        1
    }
end

local function set_fsr_textures(vp)

    local function check_handle(key)
        if fsr_textures[key] then
            bgfx.destroy(fsr_textures[key])
        end
        fsr_textures[key] = bgfx.create_texture2d(vp.w, vp.h, false, 1, "RGBA16F", flags)
    end

    local mq = w:first "main_queue render_target:in camera_ref:in"
    local main_fb = fbmgr.get(mq.render_target.fb_idx)
    local fq = w:first "fsr_resolve_queue render_target:update"
    local fsr_fbidx = fq.render_target.fb_idx
    local fsr_fb = fbmgr.get(fsr_fbidx)
    local rbidx = fsr_fb[1].rbidx
    fbmgr.resize_rb(rbidx, vp.w, vp.h)
    fbmgr.recreate(fsr_fbidx, fsr_fb)
    irq.update_rendertarget("fsr_resolve_queue", fq.render_target)
    fsr_fb = fbmgr.get(fsr_fbidx)
    fsr_textures.source_scene_handle    = fbmgr.get_rb(main_fb[1].rbidx).handle
    fsr_textures.resolved_scene_handle  = fbmgr.get_rb(fsr_fb[1].rbidx).handle
    check_handle("easu_handle")
    check_handle("rcas_handle")
end

local function set_fsr_params(vp)
    fsr_params = {
        {vp.w*scene_ratio, vp.h*scene_ratio, rcasAttenuation, 0},
        {vp.w, vp.h, 0, 0},
        {vp.w, vp.h, 0, 0}
    }
end

local function update_easu_builder(easu)
    if not easu then return end
    local easu_dis = easu.dispatch
    easu_dis.material.s_image_input  = icompute.create_image_property(fsr_textures.resolved_scene_handle, 0, 0, "r")
    easu_dis.material.s_image_output = icompute.create_image_property(fsr_textures.easu_handle, 1, 0, "w")
    easu_dis.material.u_params       = math3d.array_vector(fsr_params)
end

local function update_rcas_builder(rcas)
    if not rcas then return end
    local rcas_dis = rcas.dispatch
    rcas_dis.material.s_image_input  = icompute.create_image_property(fsr_textures.easu_handle, 0, 0, "r")
    rcas_dis.material.s_image_output = icompute.create_image_property(fsr_textures.rcas_handle, 1, 0, "w")
    rcas_dis.material.u_params       = math3d.array_vector(fsr_params)
end

function fsr_sys:init()
    local vp = world.args.viewport
    local function create_fsr_resolve_queue()
        local fsr_resolve_fbidx = fbmgr.create({rbidx = fbmgr.create_rb{w = vp.w, h = vp.h, layers = 1, format = "RGBA16F", flags = flags}}) 
        util.create_queue(fsr_resolve_viewid, mu.copy_viewrect(world.args.viewport), fsr_resolve_fbidx, "fsr_resolve_queue", "fsr_resolve_queue")
    end

    create_fsr_resolve_queue()
end

function fsr_sys:init_world()
    local vp = world.args.viewport

    local function create_fsr_resolve_entity()
        local function to_mesh_buffer(vbbin, ib_handle)
            local numv = #vbbin // layout.stride
            local numi = (numv // 4) * 6 --6 for one quad 2 triangles and 1 triangle for 3 indices
        
            return {
                bounding = nil,
                vb = {
                    start = 0,
                    num = numv,
                    handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vbbin), layout.handle),
                },
                ib = {
                    start = 0,
                    num = numi,
                    handle = ib_handle,
                }
            }
        end
        --[[
            v1---v3
            |    |
            v0---v2
        ]]
        local VBFMT<const> = ("fffff"):rep(4)
        local vb = VBFMT:pack(
            -1, 0, 0, 0, 1,
            -1, 1, 0, 0, 0,
             0, 0, 0, 1, 1,
             0, 1, 0, 1, 0)

        world:create_entity{
            policy = {
                "ant.render|simplerender",
            },
            data = {
                simplemesh          = to_mesh_buffer(vb, irender.quad_ib()),
                material            = "/pkg/ant.resources/materials/postprocess/fsr_resolve.material",
                visible_state       = "fsr_resolve_queue",
                fsr_resolve_drawer  = true,
                scene               = {},
            }
        }
    end

    set_fsr_disptach_size(vp)

    local function create_fsr_easu_entity()
       icompute.create_compute_entity(
            "fsr_easu_builder", "/pkg/ant.resources/materials/postprocess/fsr_easu.material", fsr_dispatch_size)
    end

    local function create_fsr_rcas_entity()
       icompute.create_compute_entity(
            "fsr_rcas_builder", "/pkg/ant.resources/materials/postprocess/fsr_rcas.material", fsr_dispatch_size)
    end

    set_fsr_disptach_size(vp)
    set_fsr_textures(vp)
    set_fsr_params(vp)
    create_fsr_resolve_entity()
    create_fsr_easu_entity()
    create_fsr_rcas_entity()
end

function fsr_sys:entity_init()
    local easu = w:first "INIT fsr_easu_builder dispatch:in"
    update_easu_builder(easu)
    local rcas = w:first "INIT fsr_rcas_builder dispatch:in"
    update_rcas_builder(rcas)
end

local vp_changed_mb = world:sub{"world_viewport_changed"}

function fsr_sys:data_changed()
    for _, vp in vp_changed_mb:unpack() do
        irq.set_view_rect("fsr_resolve_queue", vp)
        set_fsr_disptach_size(vp)
        set_fsr_textures(vp)
        set_fsr_params(vp)
        local easu = w:first "fsr_easu_builder dispatch:in"
        update_easu_builder(easu)
        local rcas = w:first "fsr_rcas_builder dispatch:in"
        update_rcas_builder(rcas)
        break
    end
end

function fsr_sys:fsr_resolve()
    local fsrrde = w:first "fsr_resolve_drawer filter_material:in"
    imaterial.set_property(fsrrde, "s_scene_color", fsr_textures.source_scene_handle)
end

function fsr_sys:fsr_easu()
    for ve in w:select "fsr_easu_builder dispatch:in" do
        local dis = ve.dispatch
        dis.size = fsr_dispatch_size
        icompute.dispatch(fsr_easu_viewid, dis)  
    end
end

function fsr_sys:fsr_rcas()
    for ve in w:select "fsr_rcas_builder dispatch:in" do
        local dis = ve.dispatch
        dis.size = fsr_dispatch_size
        icompute.dispatch(fsr_rcas_viewid, dis)  
    end
end

return ifsr
local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local viewidmgr, fbmgr = renderpkg.viewidmgr, renderpkg.fbmgr
local sampler   = renderpkg.sampler

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant
local math3d    = require "math3d"

local ientity   = ecs.import.interface "ant.render|ientity"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local irender   = ecs.import.interface "ant.render|irender"
local iibl      = ecs.import.interface "ant.render|iibl"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local icamera   = ecs.import.interface "ant.camera|icamera"

local panorama_util=require "panorama.util"

local cvt_p2cm_viewid = viewidmgr.get "panorama2cubmap"

local render2cm_sys = ecs.system "render2cm_system"

local face_queues<const> = {
    "cubemap_face_queue_px",
    "cubemap_face_queue_nx",
    "cubemap_face_queue_py",
    "cubemap_face_queue_ny",
    "cubemap_face_queue_pz",
    "cubemap_face_queue_nz",
}

local function create_face_queue(queuename, cameraref)
    ecs.create_entity{
        policy = {
            "ant.render|render_queue",
            "ant.general|name",
        },
        data = {
            name = queuename,
            [queuename] = true,
            queue_name = queuename,
            render_target = {
                viewid = cvt_p2cm_viewid,
                view_rect = {x=0, y=0, w=1, h=1},
                clear_state = {clear = ""},
                fb_idx = nil,
            },
            primitive_filter = {filter_type = "",},
            visible = false,
            camera_ref = cameraref,
        }
    }
end

function render2cm_sys:init()
    local cameraref = icamera.create()
    for _, fn in ipairs(face_queues) do
        create_face_queue(fn, cameraref)
    end
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = {vb={num=3}},
            scene = {srt={}},
            material = "/pkg/ant.sky/panorama/render2cm.material",
            filter_state = "",
            cvt_p2cm_drawer = true,
            name = "cvt_p2cm_drawer",
        }
    }

    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = {vb={num=3}},
            material = "/pkg/ant.sky/panorama/filter_ibl.material",
            scene = {srt={}},
            filter_state = "",
            name = "filter_drawer",
            filter_drawer = true,
        }
    }
end

local cubemap_flags<const> = sampler.sampler_flag {
    MIN="LINEAR",
    MAG="LINEAR",
    MIP="LINEAR",
    U="CLAMP",
    V="CLAMP",
    W="CLAMP",
    RT="RT_ON",
}

function render2cm_sys:entity_ready()
    for e in w:select "skybox_changed skybox:in render_object:in filter_ibl?out" do
        local tex = imaterial.get_property(e, "s_skybox").value.texture

        local ti = tex.texinfo
        if panorama_util.is_panorama_tex(ti) then
            if e.skybox.facesize == nil then
                e.skybox.facesize = ti.height // 2
            end
            local facesize = e.skybox.facesize
            local cm_rbidx = panorama_util.check_create_cubemap_tex(facesize, e.skybox.cubeme_rbidx, cubemap_flags)
            e.skybox.cubeme_rbidx = cm_rbidx

            local drawer = w:singleton("cvt_p2cm_drawer", "render_object:in")
            local ro = drawer.render_object
            ro.worldmat = mc.IDENTITY_MAT
            ro.material.s_tex = tex.handle

            for idx, fn in ipairs(face_queues) do
                local faceidx = idx-1
                local fbidx = fbmgr.create{
                    rbidx = cm_rbidx,
                    layer = faceidx,
                    resolve = "g",
                    mip = 0,
                    numlayer = 1,
                }
                local q = w:singleton(fn, "render_target:in")
                local rt = q.render_target
                local vr = rt.view_rect
                vr.x, vr.y, vr.w, vr.h = 0, 0, facesize, facesize
                rt.viewid = cvt_p2cm_viewid + faceidx
                rt.fb_idx = fbidx
                irq.update_rendertarget(fn, rt)

                ro.material.u_param = math3d.vector(faceidx, 0.0, 0.0, 0.0)

                irender.draw(rt.viewid, ro)

                local keep_rbs<const> = true
                fbmgr.destroy(fbidx, keep_rbs)
            end
            imaterial.set_property(e, "s_skybox", {stage=0, texture={handle=fbmgr.get_rb(cm_rbidx).handle}})
            e.filter_ibl = true
        end
    end
end

local sample_count<const> = 2048
local cLambertian<const>   = 0
local cGGX       <const>   = 1
local cCharlie   <const>   = 2

local face_size <const>    = 256
--[[
#define u_roughness     u_ibl_params.x
#define u_sampleCount   u_ibl_params.y
#define u_width         u_ibl_params.z
#define u_lodBias       u_ibl_params.w

#define u_distribution  u_ibl_params1.x
#define u_currentFace   u_ibl_params1.y
#define u_isGeneratingLUT u_ibl_params1.z
]]

local ibl_properties = {
    irradiance = {
        u_ibl_params = {0.0, sample_count, face_size, 0.0},
        u_ibl_params1= {cLambertian, 0.0, 0.0, 0.0},
    },
    prefilter = {
        u_ibl_params = {0.0, sample_count, face_size, 0.0},
        u_ibl_params1= {cGGX, 0.0, 0.0, 0.0},
    },
    LUT = {
        u_ibl_params = {0.0, 0.0, 0.0, 0.0},
        u_ibl_params1= {0.0, 0.0, 1.0, 0.0},
    }
}

local build_ibl_viewid = viewidmgr.get "build_ibl"

local function build_irradiance_map(source_tex, irradiance, facesize)
    local irradiance_rbidx = fbmgr.create_rb{format="RGBA32F", size=facesize, layers=1, flags=cubemap_flags, cubemap=true}

    local drawer = w:singleton("filter_drawer", "render_object:in")
    local ro = drawer.render_object
    ro.worldmat = mc.IDENTITY_MAT
    -- do for irradiance
    local irradiance_properties = ibl_properties.irradiance

    imaterial.set_property(drawer, "s_source", source_tex)

    for idx, fn in ipairs(face_queues) do
        local faceidx = idx-1
        local q = w:singleton(fn, "render_target:in")
        local rt = q.render_target
        rt.viewid = build_ibl_viewid+faceidx
        local vr = rt.view_rect
        vr.x, vr.y, vr.w, vr.h = 0, 0, facesize, facesize

        local fbidx = fbmgr.create{
            rbidx = irradiance_rbidx,
            layer = faceidx,
            mip = 0,
            numlayer = 1,
        }
        rt.fb_idx = fbidx
        irq.update_rendertarget(fn, rt)
        local p, p1 = irradiance_properties.u_ibl_params, irradiance_properties.u_ibl_params1
        p1[2] = faceidx
        imaterial.set_property(drawer, "u_ibl_params", p)
        imaterial.set_property(drawer, "u_ibl_params1", p1)
        irender.draw(rt.viewid, ro)

        fbmgr.destroy(fbidx, true)
    end

    irradiance.rbidx = irradiance_rbidx
    irradiance.handle = fbmgr.get_rb(irradiance_rbidx).handle
    irradiance.size = facesize
end

local function build_prefilter_map(source_tex, prefilter, facesize)
    local prefilter_rbidx = fbmgr.create_rb{format="RGBA32F", size=facesize, layers=1, flags=cubemap_flags, cubemap=true}

    prefilter.rbidx = prefilter_rbidx
    prefilter.mipmap_count = math.log(facesize)+1
    prefilter.handle = fbmgr.get_rb(prefilter_rbidx).handle
    prefilter.size = facesize
end

local function build_LUT_map(source_tex, LUT, size)
    local LUT_rbidx = fbmgr.create_rb{format="RG32F", w=size, h=size, layers=1, flags=cubemap_flags}

    LUT.rbidx = LUT_rbidx
    LUT.handle = fbmgr.get_rb(LUT_rbidx).handle
    LUT.size = size
end

function render2cm_sys:filter_ibl()
    for e in w:select "filter_ibl ibl:in render_object:in" do
        local source_tex = imaterial.get_property(e, "s_skybox").value
        local ibl_textures = iibl.get_ibl_textures()
        ibl_textures.intensity = 12000

        local irradiance_face_size<const> = 32
        build_irradiance_map(source_tex, ibl_textures.irradiance, irradiance_face_size)
        local prefilter_face_size<const> = 256
        build_prefilter_map(source_tex, ibl_textures.prefilter, prefilter_face_size)
        local LUT_size<const> = 256
        build_LUT_map(source_tex, ibl_textures.LUT, LUT_size)
    end
    w:clear "filter_ibl"
end
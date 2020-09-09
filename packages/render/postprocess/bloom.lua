local ecs = ...
local world = ecs.world

local setting		= import_package "ant.settings".setting

local viewidmgr = require "viewid_mgr"
local fbmgr    = require "framebuffer_mgr"
local renderutil= require "util"

local fs        = require "filesystem"

local bloom_sys = ecs.system "bloom_system"

local ipp = world:interface "ant.render|postprocess"
local imaterial world:interface "ant.asset|imaterial"

local bloom_chain_count = 4

local function create_framebuffers_container_obj(fbsize)
    local flags = renderutil.generate_sampler_flag {
        RT="RT_ON",
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
    }

    local sd = setting:data()
    local bloomsetting = sd.graphic.postprocess.bloom
    local fmt = bloomsetting.format
    local t = {}
    for i=1, 2 do
        t[i] = fbmgr.create {
            render_buffers = {
                fbmgr.create_rb {
                    format = fmt,
                    w = fbsize.w, h = fbsize.h,
                    layers = 1, flags = flags,
                }
            },
        }
    end
    return t
end

local bloompath = fs.path "/pkg/ant.resources/materials/postprocess"

local downsample_material   = bloompath / "downsample.material"
local upsample_material     = bloompath / "upsample.material"
local combine_material      = bloompath / "combine.material"

local function get_passes_settings(main_fbidx, fb_indices, fbw, fbh)
    local passes = {}

    local which_fb = 0
    local numfb = #fb_indices
    local function next_fbidx()
        which_fb = (which_fb % numfb) + 1
        return fb_indices[which_fb]
    end

    local function insert_blur_pass(fbw, fbh, material, sampleparam, intensity)
        local passidx = #passes+1
        local fbidx = next_fbidx()
        local pass = ipp.create_pass(
            material,
            {
                view_rect = {x=0, y=0, w=fbw, h=fbh},
                clear_state = {clear=""},
                fb_idx    = fbidx,
            }, 
            ipp.get_rbhandle(fbidx, 1),
            "bloom" .. passidx
        )
        passes[passidx] = pass

        local eid = pass.eid
        imaterial.set_property(eid, "u_sample_param", sampleparam)
        if intensity then
            imaterial.set_property(eid, "u_intensity", intensity)
        end
    end

    local function create_sample_param_uniform(w, h)
        return {w / fbw, h / fbh, 1 / w, 1 / h}
    end

    for ii=1, bloom_chain_count do
        local sampleparam = create_sample_param_uniform(fbw, fbh)
        fbw, fbh = math.floor(fbw*0.5), math.floor(fbh*0.5)
        insert_blur_pass(fbw, fbh, downsample_material, sampleparam)
    end

    local intensity<const> = {1.2, 0.0, 0.0, 0.0}
    for ii=bloom_chain_count+1, bloom_chain_count*2 do
        local sampleparam = create_sample_param_uniform(fbw, fbh)
        fbw, fbh = fbw*2, fbh*2
        insert_blur_pass(fbw, fbh, upsample_material, sampleparam, intensity)
    end

    local fbidx = next_fbidx()
    passes[#passes+1] = ipp.create_pass(
        combine_material, 
        {
            view_rect = {x=0, y=0, w=fbw, h=fbh},
            clear_state = {clear=""},
            fb_idx = fbidx,
        },
        ipp.get_rbhandle(fbidx, 1),
        "combine_bloom_with_scene"
    )

    assert(passes[1].input == nil)
    passes[1].input = {fb_idx=main_fbidx, rb_idx=2}
    return passes
end

function bloom_sys:post_init()
    local sd = setting:data()
    local bloom = sd.graphic.postprocess.bloom
    if bloom.enable then
        local main_fbidx = fbmgr.get_fb_idx(viewidmgr.get "main_view")
        local w, h = ipp.main_rb_size(main_fbidx)
        ipp.add_technique {
            name = "bloom",
            passes = get_passes_settings(main_fbidx, create_framebuffers_container_obj(w, h), w, h),
        }
    end
end

local ecs   = ...
local world = ecs.world
local w     = world.w

local setting	= import_package "ant.settings".setting

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"

local bloom_sys = ecs.system "bloom_system"

local imaterial = ecs.import.interface "ant.asset|imaterial"

local bloom_chain_count = 4

local function create_framebuffers_container_obj(fbw, fbh)
    local flags = sampler.sampler_flag {
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
                fbmgr.create_rb {
                    format = fmt,
                    w = fbw, h = fbh,
                    layers = 1, flags = flags,
                }
            }
    end
    return t
end

local bloompath = "/pkg/ant.resources/materials/postprocess/"

local downsample_material   = bloompath .. "downsample.material"
local upsample_material     = bloompath .. "upsample.material"
local combine_material      = bloompath .. "combine.material"

local function get_passes_settings(main_fbidx, fb_indices, fb_width, fb_height)
    local passes = {}

    local which_fb = 0
    local numfb = #fb_indices
    local function next_fbidx()
        which_fb = (which_fb % numfb) + 1
        return fb_indices[which_fb]
    end

    local function insert_blur_pass(fbw, fbh, material, sampleparam, intensity)
        local passidx = #passes+1
        local pass = ipp.create_pass(
            "bloom" .. passidx,
            material,
            {
                view_rect   = {x=0, y=0, w=fbw, h=fbh},
                clear_state = {clear=""},
                fb_idx      = next_fbidx(),
            }
        )
        passes[passidx] = pass

        local eid = pass.eid
        imaterial.set_property(eid, "u_sample_param", sampleparam)
        if intensity then
            imaterial.set_property(eid, "u_intensity", intensity)
        end
    end

    local function create_sample_param_uniform(w, h)
        return {w / fb_width, h / fb_height, 1 / w, 1 / h}
    end

    local fbw, fbh = fb_width, fb_height
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
    passes[#passes+1] = ipp.create_pass(
        "combine_bloom_with_scene",
        combine_material, 
        {
            view_rect = {x=0, y=0, w=fb_width, h=fb_height},
            clear_state = {clear=""},
            fb_idx = next_fbidx(),
        }
    )

    passes[1].input = ipp.get_rbhandle(main_fbidx, 2)
    return passes
end

function bloom_sys:post_init()
    local sd = setting:data()
    local bloom = sd.graphic.postprocess.bloom
    if bloom.enable then
        local fbidx = fbmgr.get_fb_idx(viewidmgr.get "main_view")
        local w, h = ipp.main_rb_size(fbidx)
        ipp.add_technique("bloom", 
            get_passes_settings(fbidx, create_framebuffers_container_obj(w, h), w, h))
    end
end

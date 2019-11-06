local ecs = ...
local world = ecs.world

local viewidmgr = require "viewid_mgr"
local fbgmgr    = require "framebuffer_mgr"
local renderutil= require "util"
local computil  = require "components.util"
local setting   = require "setting"

local fs        = require "filesystem"

local bloom_sys = ecs.system "bloom_system"
bloom_sys.depend    "render_system"
bloom_sys.dependby  "postprocess_system"
bloom_sys.dependby  "tonemapping"

local bloom_chain_count = 4

ecs.tag "bloom"

local function get_bloom_blur_sample_names()
    local names = {}
    for ii=1, bloom_chain_count do
        names[#names+1] = "bloom_downsample" .. ii
    end

    for ii=1, bloom_chain_count do
        names[#names+1] = "bloom_upsample" .. ii
    end
    return names
end

local bloom_blur_sample_viewid_names = get_bloom_blur_sample_names()

local function create_bloom_viewids()
    local viewids = {
        bloom_fetch_bright  = viewidmgr.generate "bloom_fetch_bright",
        bloom_combine       = viewidmgr.generate "bloom_combine"
    }

    for _, name in ipairs(bloom_blur_sample_viewid_names) do
        viewids[name] = viewidmgr.generate(name)
    end

    return viewids
end

local viewids = create_bloom_viewids()

local function create_framebuffers_container_obj(fbsize)
    local flags = renderutil.generate_sampler_flag {
        RT="RT_ON",
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
    }

    local sd = setting.get()
    local bloomsetting = sd.graphic.postprocess.bloom
    local fmt = bloomsetting.format
    return {
        fbgmgr.create {
            render_buffers = {
                fbgmgr.create_rb {
                    format = fmt,
                    w = fbsize.w, h = fbsize.h,
                    layers = 1, flags = flags,
                }
            },
        },
        fbgmgr.create {
            render_buffers = {
                fbgmgr.create_rb {
                    format = fmt,
                    w = fbsize.w, h = fbsize.h,
                    layers = 1, flags = flags,
                }
            }
        }
    }
end

local function bind_fb_with_viewids(viewids, fb_indices)
    local sel_idx = 0
    local num_swap_fb = #fb_indices
    local function next_idx()
        sel_idx = (sel_idx % num_swap_fb) + 1
        return sel_idx
    end

    for _, name in ipairs(bloom_blur_sample_viewid_names) do
        fbgmgr.bind(viewids[name], fb_indices[next_idx()])
    end

    fbgmgr.bind(viewids["bloom_combine"], fb_indices[next_idx()])
end

local bloompath = fs.path "/pkg/ant.resources/depiction/materials/postprocess"

local downsample_material   = bloompath / "downsample.material"
local upsample_material     = bloompath / "upsample.material"
local combine_material      = bloompath / "combine.material"

local function get_passes_settings(main_viewid, viewids, fbsize)
    local passes = {}
    local fbw, fbh = fbsize.w, fbsize.h

    local function get_viewport(w, h)
        return {
            clear_state = {clear=""},
            rect = {x=0, y=0, w=w or fbsize.w, h= h or fbsize.h},
        }
    end

    local function insert_blur_pass(output_passidx, fbw, fbh, material)
        local viewidname = bloom_blur_sample_viewid_names[output_passidx]
        local output_viewid = viewids[viewidname]
        passes[#passes+1] = {
            name = "bloom:" .. viewidname,
            material = computil.assign_material(material),
            viewport = get_viewport(fbw, fbh),
            output = {viewid=output_viewid, slot=1},
        }
    end
    for ii=1, bloom_chain_count do
        fbw, fbh = math.floor(fbw*0.5), math.floor(fbh*0.5)
        insert_blur_pass(ii, fbw, fbh, downsample_material)
    end

    for ii=bloom_chain_count+1, bloom_chain_count*2 do
        fbw, fbh = fbw*2, fbh*2
        insert_blur_pass(ii, fbw, fbh, upsample_material)
    end

    passes[#passes+1] = {
        name = "combine scene with bloom",
        material = computil.assign_material(combine_material),
        viewport = get_viewport(),
        output  = {viewid=viewids["bloom_combine"], slot=1},
    }

    assert(passes[1].input == nil)
    passes[1].input = {viewid=main_viewid, slot=2}
    return passes
end

function bloom_sys:post_init()
    local pp_eid = world:first_entity_id "postprocess"
    local main_viewid = viewidmgr.get "main_view"
    bind_fb_with_viewids(viewids, create_framebuffers_container_obj(world.args.fb_size))

    world:add_component(pp_eid, "technique", {
        {
            name = "bloom",
            passes = get_passes_settings(main_viewid, viewids, world.args.fb_size),
        }
    })
end

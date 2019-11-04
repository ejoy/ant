local ecs = ...
local world = ecs.world

local viewidmgr = require "viewid_mgr"
local fbgmgr    = require "framebuffer_mgr"
local renderutil= require "util"
local computil  = require "components.util"


local fs        = require "filesystem"

local bloom_sys = ecs.system "bloom_system"
bloom_sys.depend    "render_system"
bloom_sys.dependby  "postprocess_system"

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

local fb_indices

local function create_framebuffers_container_obj(fbsize)
    local flags = renderutil.generate_sampler_flag {
        RT="RT_ON",
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
    }

    fb_indices = {
        fbgmgr.create {
            fbgmgr.create_rb {
                format = "RGBA8",
                width = fbsize.w, height = fbsize.h,
                layer = 1, flags = flags,
            }
        },
        fbgmgr.create {
            fbgmgr.create_rb {
                format = "RGBA8",
                width = fbsize.w, height = fbsize.h,
                layer = 1, flags = flags,
            }
        }
    }
end

local function bind_fb_with_viewids(viewids, fbeid)
    local fb_entity = world[fbeid]
    local fbs = fb_entity.framebuffers

    local fbidx = 1
    fbgmgr.bind(viewids["bloom_fetch_bright"], fbidx)

    for _, name in ipairs(bloom_blur_sample_viewid_names) do
        fbidx = (fbidx // 2) + 1
        fbgmgr.bind(viewids[name], fbs[fbidx])
    end

    fbidx = (fbidx // 2) + 1
    fbgmgr.bind(viewids["bloom_combine"], fbs[fbidx])
end

local bloompath = fs.path "/pkg/ant.resources/depiction/materials/bloom"

local fetch_bright_material = bloompath / "fetch_bright.material"
local downsample_material   = bloompath / "downsample.material"
local upsample_material     = bloompath / "upsample.material"
local combine_material      = bloompath / "combine.material"
local copy_quad_material    = bloompath / "copy_quad.material"

local function get_passes_settings(main_viewid, viewids, fbsize)
    local passes = {}
    local fbw, fbh = fbsize.w, fbsize.h
    local start_viewid = main_viewid

    local function default_viewport()
        return {
            clear_state = {color=0, clear="C"},
            rect = {x=0, y=0, w=fbsize.w, h=fbsize.h},
        }
    end

    passes[#passes+1] = {
        name = "fetch bright value by threshold value",
        material = computil.assign_material(fetch_bright_material, {
            uniforms = {
                u_bright_threshold = {
                    type="color", 
                    name = "bright value threshold(linear value, [0, 1])", 
                    value = {0.75, 0.0, 0.0, 0.0}
                },
            }
        }),
        viewport= default_viewport(),
        input   = start_viewid,
        output  = viewids["bloom_fetch_bright"],
    }

    local function insert_blur_pass(input_viewid, output_passidx, fbw, fbh, material)
        local viewidname = bloom_blur_sample_viewid_names[output_passidx]
        local output_viewid = viewids[viewidname]
        passes[#passes+1] = {
            name = "bloom:" .. viewidname,
            material = computil.assign_material(material),
            viewport = {
                clear_state = {color=0, clear="C"},
                rect = {x=0,y=0,w=fbw, h=fbh},
            },
            input = input_viewid,
            output = output_viewid,
        }
        return output_viewid
    end
    for ii=1, bloom_chain_count do
        fbw, fbh = fbw*0.5, fbh*0.5
        start_viewid = insert_blur_pass(start_viewid, ii, fbw, fbh, downsample_material)
    end

    for ii=bloom_chain_count, bloom_chain_count*2 do
        fbw, fbh = fbw*2, fbh*2
        start_viewid = insert_blur_pass(start_viewid, ii, fbw, fbh, upsample_material)
    end

    passes[#passes+1] = {
        name = "combine scene with bloom",
        material = computil.assign_material(combine_material),
        viewport = default_viewport(),

        input   = start_viewid,
        output  = viewids["bloom_combine"],
    }

    --TODO: we need a copy resource system to handle this. 
    --      here, we just render another quad to copy the result back to main viewid, it will lost performance
    passes[#passes+1] = {
        name = "copy bloom result",
        material = computil.assign_material(copy_quad_material),
        viewport = default_viewport(),
        input   = viewids["bloom_combine"],
        output  = main_viewid,
    }
end

function bloom_sys:post_init()
    local pp_eid = world:first_entity_eid "postprocess"
    local main_viewid = viewidmgr.get "main_view"
    bind_fb_with_viewids(viewids, create_framebuffers_container_obj(world.arg.fb_size))

    world:add_component(pp_eid, "technique", {
        name = "bloom",
        passes = get_passes_settings(main_viewid, viewids, world.arg.fb_size),
    })
end

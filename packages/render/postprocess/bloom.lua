local ecs = ...
local world = ecs.world

local viewidmgr = require "viewid_mgr"
local fbgmgr    = require "framebuffer_mgr"
local renderutil= require "util"
local computil  = require "components.util"
local setting   = require "setting"

local fs        = require "filesystem"

local bloom_sys = ecs.system "bloom_system"
bloom_sys.step "bloom"
bloom_sys.singleton "postprocess"
bloom_sys.depend    "render_system"
bloom_sys.dependby  "postprocess_system"
bloom_sys.dependby  "tonemapping"

local bloom_chain_count = 4

ecs.tag "bloom"

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

local bloompath = fs.path "/pkg/ant.resources/depiction/materials/postprocess"

local downsample_material   = bloompath / "downsample.material"
local upsample_material     = bloompath / "upsample.material"
local combine_material      = bloompath / "combine.material"

local function get_passes_settings(main_fbidx, fb_indices, fbsize)
    local passes = {}
    local fbw, fbh = fbsize.w, fbsize.h

    local function get_viewport(w, h)
        return {
            clear_state = {clear=""},
            rect = {x=0, y=0, w=w or fbsize.w, h= h or fbsize.h},
        }
    end

    local function insert_blur_pass(fbidx, fbw, fbh, material, sampleparam, intensity)
        local passidx = #passes+1
        local properties = {
            uniforms = {
                u_sample_param = {
                    type = "v4", name = "sample param", value = sampleparam,
                },
            }
        }

        if intensity then
            properties.uniforms["u_intensity"] = {
                type = "v4", name = "up sample intensity", value = {intensity, 0.0, 0.0, 0.0},
            }
        end

        passes[passidx] = {
            name = "bloom" .. passidx,
            material = computil.assign_material(material, properties),
            viewport = get_viewport(fbw, fbh),
            output = {fb_idx=fbidx, rb_idx=1},
        }
    end

    local fbidx = 0
    local numfb = #fb_indices
    local function next_fbidx()
        fbidx = (fbidx % numfb) + 1
        return fb_indices[fbidx]
    end

    local function create_sample_param_uniform(fbw, fbh)
        local scalex, scaley = fbw / fbsize.w, fbh / fbsize.h
        local texelsizex, texelsizey = 1 / fbw, 1 / fbh
        return {scalex, scaley, texelsizex, texelsizey}
    end

    for ii=1, bloom_chain_count do
        local sampleparam = create_sample_param_uniform(fbw, fbh)
        fbw, fbh = math.floor(fbw*0.5), math.floor(fbh*0.5)
        insert_blur_pass(next_fbidx(), fbw, fbh, downsample_material, sampleparam)
    end

    for ii=bloom_chain_count+1, bloom_chain_count*2 do
        local sampleparam = create_sample_param_uniform(fbw, fbh)
        fbw, fbh = fbw*2, fbh*2
        insert_blur_pass(next_fbidx(), fbw, fbh, upsample_material, sampleparam, 1.2)
    end

    passes[#passes+1] = {
        name = "combine scene with bloom",
        material = computil.assign_material(combine_material),
        viewport = get_viewport(),
        output  = {fb_idx=next_fbidx(), rb_idx=1},
    }

    assert(passes[1].input == nil)
    passes[1].input = {fb_idx=main_fbidx, rb_idx=2}
    return passes
end

function bloom_sys:post_init()
    local pp = self.postprocess

    local sd = setting.get()
    local bloom = sd.graphic.postprocess.bloom
    if bloom.enable then
        local main_fbidx = fbgmgr.get_fb_idx(viewidmgr.get "main_view")

        local fbsize = world.args.fb_size
        local techniques = pp.techniques
        techniques[#techniques+1] = {
            name = "bloom",
            passes = get_passes_settings(main_fbidx, create_framebuffers_container_obj(fbsize), fbsize),
        }
    end
end

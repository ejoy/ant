local ecs   = ...
local world = ecs.world
local w     = world.w


local setting   = import_package "ant.settings"
local blur_sys  = ecs.system "blur_system"

if not setting:get "graphic/postprocess/blur/enable" then
    return
end

local math3d    = require "math3d"
local ips       = ecs.require "ant.render|postprocess.pyramid_sample"
local hwi       = import_package "ant.hwi"

local BLUR_DS_VIEWID <const> = hwi.viewid_get "blur_ds1"
local BLUR_US_VIEWID <const> = hwi.viewid_get "blur_us1"
local VBLUR_VIEWID   <const> = hwi.viewid_get "vblur"
local HBLUR_VIEWID   <const> = hwi.viewid_get "hblur"
local BLUR_PARAM = math3d.ref(math3d.vector(0, 0, 0, 0))
local BLUR_WIDTH, BLUR_HEIGHT
local THREAD_GROUP_SIZE <const> = 16

local iblur = {}

local function register_blur_queue()
    local blur_mipcount = ips.get_pyramid_mipcount()
    for i=1, blur_mipcount do
        local ds_queue  = "blur_downsample"..i
        local us_queue  = "blur_upsample"..i
        w:register{name = ds_queue}
        w:register{name = us_queue}
    end
end

--[[ local function build_gaussian_blur()
    local gb = {}
    local flags<const> = sampler {
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
        BLIT="BLIT_COMPUTEWRITE",
    }
    local dispatchsize = {math.floor(BLUR_WIDTH / THREAD_GROUP_SIZE), math.floor(BLUR_HEIGHT // THREAD_GROUP_SIZE), 1}
    gb.vblur = icompute.create_compute_entity("vblur_drawer", "/pkg/ant.resources/materials/vblur.material", dispatchsize)
    gb.hblur = icompute.create_compute_entity("hblur_drawer", "/pkg/ant.resources/materials/hblur.material", dispatchsize)
    gb.tmp_texture = bgfx.create_texture2d(BLUR_WIDTH, BLUR_HEIGHT, false, 1, "RGBA8", flags)
    return gb
end ]]

local function create_blur_entity(mqvr)
    world:create_entity{
        policy = {
            "ant.render|pyramid_sample",
            "ant.render|blur"
        },
        data = {
            blur = true,
            pyramid_sample = {
                downsample_queue = "blur_downsample",
                upsample_queue = "blur_upsample",
                downsample_viewid = BLUR_DS_VIEWID,
                upsample_viewid = BLUR_US_VIEWID,
                queue_name = "blur_queue",
                sample_params = BLUR_PARAM,
            },
            on_ready = function (e)
                w:extend(e, "pyramid_sample:update")
                ips.set_pyramid_sample_components(e, mqvr)
            end
            --gaussian_blur = build_gaussian_blur()
        }
    }
end

function blur_sys:init()
    register_blur_queue()
end

function blur_sys:init_world()
    local mq = w:first("main_queue render_target:in")
    local mqvr = mq.render_target.view_rect
    BLUR_WIDTH, BLUR_HEIGHT = mqvr.w, mqvr.h
    create_blur_entity(mqvr)
end

--[[ function iblur.do_gaussian_blur(be)

    local function set_gaussian_blur_params(e, input, output, viewid)
        local dis = e.dispatch
        local mi = dis.material

        mi.s_image_input = icompute.create_image_property(input, 0, 0, "r")
        mi.s_image_output= icompute.create_image_property(output, 1, 0, "w")
        icompute.dispatch(viewid, dis)
    end
    if not be then return end

    local ps = be.pyramid_sample
    local gb = be.gaussian_blur
    local source_tex =  ps.scene_color_property.value
    local tmp_texture = gb.tmp_texture
    local vblur, hblur = world:entity(gb.vblur, "dispatch:in"), world:entity(gb.hblur, "dispatch:in")
    set_gaussian_blur_params(vblur, source_tex, tmp_texture, VBLUR_VIEWID)
    set_gaussian_blur_params(hblur, tmp_texture, source_tex, HBLUR_VIEWID)
  
end

return iblur ]]
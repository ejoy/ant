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
local queuemgr  = ecs.require "queue_mgr"
local iviewport = ecs.require "viewport.state"

local BLUR_DOWNSAMPLE_NAME<const> = "blur_downsample"
local BLUR_UPSAMPLE_NAME<const> = "blur_upsample"

local BLUR_DS_VIEWID <const> = hwi.viewid_get "blur_ds1"
local BLUR_US_VIEWID <const> = hwi.viewid_get "blur_us1"
local BLUR_PARAM = math3d.ref(math3d.vector(0, 0, 0, 0))

local MIP_COUNT<const> = 4

local function register_queues()
    for i=1, MIP_COUNT do
        queuemgr.register_queue(BLUR_DOWNSAMPLE_NAME..i)
        queuemgr.register_queue(BLUR_UPSAMPLE_NAME..i)
    end

    local pyramid_sample = {
        downsample      = ips.init_sample(MIP_COUNT, "blur_downsample", BLUR_DS_VIEWID),
        upsample        = ips.init_sample(MIP_COUNT, "blur_upsample", BLUR_US_VIEWID),
        sample_params   = BLUR_PARAM,
    }
    ips.create(pyramid_sample, iviewport.viewrect)
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

function blur_sys:init()
    register_queues()
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
local ecs   = ...
local world = ecs.world
local w     = world.w

local bloom_sys = ecs.system "bloom_system"
local setting   = import_package "ant.settings".setting
local renderutil= require "util"
local bloom_setting = setting:data().graphic.postprocess.bloom
local ENABLE_BLOOM<const> = bloom_setting.enable

if not ENABLE_BLOOM then
    renderutil.default_system(bloom_sys, "init", "init_world", "data_changed", "bloom")
    return
end

local math3d    = require "math3d"

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"

local icompute  = ecs.import.interface "ant.render|icompute"
function bloom_sys:init()
    icompute.create_compute_entity("bloom_downsampler", "/pkg/ant.resources/materials/postprocess/downsample.material", {0, 0, 1})
    icompute.create_compute_entity("bloom_upsampler", "/pkg/ant.resources/materials/postprocess/upsample.material", {0, 0, 1})
end

local bloom_rb_flags<const> = sampler {
    RT="RT_ON",
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_COMPUTEWRITE"
}

local BLOOM_MIPCOUNT<const> = 4
local BLOOM_PARAM = math3d.ref(math3d.vector(0, bloom_setting.inv_highlight, bloom_setting.threshold, 0))

local bloom_viewid<const> = viewidmgr.get "bloom"

local MIN_FB_SIZE<const> = 2 ^ BLOOM_MIPCOUNT

local function is_viewrect_valid(vr)
    return (vr.w >= MIN_FB_SIZE or vr.h >= MIN_FB_SIZE)
end

local function create_bloom_rb(vr)
    return fbmgr.create_rb{
        w = vr.w,
        h = vr.h,
        format = "RGBA16F",
        layers=1,
        mipmap=true,
        flags = bloom_rb_flags,
    }
end

function bloom_sys:init_world()
    local vr = world.args.viewport
    if is_viewrect_valid(vr) then
        local be = w:first "bloom_downsampler dispatch:in"
        be.dispatch.bloom_texture_idx = create_bloom_rb(vr)
    end
end

local mqvr_mb = world:sub{"view_rect_changed", "main_queue"}
function bloom_sys:data_changed()
    for _, _, vr in mqvr_mb:unpack() do
        local be = w:first "bloom_downsampler dispatch:in"
        if is_viewrect_valid(vr) then
            if be.dispatch.bloom_texture_idx then
                fbmgr.resize_rb(be.dispatch.bloom_texture_idx, vr.w, vr.h)
            else 
                be.dispatch.bloom_texture_idx = create_bloom_rb(vr)
            end
        end
    end
end

local input_color_property = {
    type   = "i",
    value  = nil,
    stage  = 0,
    mip    = 0,
    access = "r"
}

local output_color_property = {
    type   = "i",
    value  = nil,
    stage  = 1,
    mip    = 0,
    access = "w"
}

function bloom_sys:bloom()
    local vr = world.args.viewport
    local dse = w:first "bloom_downsampler dispatch:in"
    if not is_viewrect_valid(vr) or not dse.dispatch.bloom_texture_idx then
        return
    end

    --assert(dse.dispatch.bloom_texture_idx, ("Invalid viewport size:%d, %d, at least:%d, %d"):format(vr.w, vr.h, MIN_FB_SIZE, MIN_FB_SIZE))

    local ppi = w:first "postprocess postprocess_input:in".postprocess_input

    local ds_dis = dse.dispatch
    local ds_m = ds_dis.material

    local scene_color_handle = ppi.scene_color_handle
    local bloom_handle = fbmgr.get_rb(ds_dis.bloom_texture_idx).handle

    local function output_image_size(ww, hh)
        return math.floor(ww * 0.5), math.floor(hh * 0.5)
    end

    local ww, hh = vr.w, vr.h
    local fbsizes = {ww, hh}

    for mip=1, BLOOM_MIPCOUNT do
        BLOOM_PARAM[1] = mip-1
        ds_m.u_bloom_param = BLOOM_PARAM

        ww, hh = output_image_size(ww, hh)
        ds_m.u_bloom_param2 = math3d.vector(ww, hh, 1.0/ww, 1.0/hh)
        fbsizes[#fbsizes+1] = ww
        fbsizes[#fbsizes+1] = hh
        icompute.calc_dispatch_size_2d(ww, hh, ds_dis.size)

        input_color_property.value = mip == 1 and scene_color_handle or bloom_handle
        input_color_property.mip = mip-1
        ds_m.s_color_input = input_color_property

        output_color_property.value = bloom_handle
        output_color_property.mip = mip
        ds_m.s_color_output = output_color_property

        icompute.dispatch(bloom_viewid, ds_dis)
    end

    local use = w:first "bloom_upsampler dispatch:in"
    local us_dis = use.dispatch
    local us_m = us_dis.material

    input_color_property.value = bloom_handle
    output_color_property.value = bloom_handle

    for mip=BLOOM_MIPCOUNT, 1, -1 do
        BLOOM_PARAM[1] = mip-1
        us_m.u_bloom_param = BLOOM_PARAM
        ww, hh = fbsizes[mip*2-1], fbsizes[mip*2]
        us_m.u_bloom_param2 = math3d.vector(ww, hh, 1.0/ww, 1.0/hh)
        icompute.calc_dispatch_size_2d(ww, hh, us_dis.size)

        input_color_property.mip = mip
        us_m.s_color_input = input_color_property

        output_color_property.mip = mip-1
        us_m.s_color_output = output_color_property

        icompute.dispatch(bloom_viewid, us_dis)
    end

    assert(vr.w == ww and vr.h == hh)
    assert(output_color_property.mip == 0)

    ppi.bloom_color_handle = bloom_handle
end

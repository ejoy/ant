local ecs   = ...
local world = ecs.world
local w     = world.w

local setting = import_package "ant.settings"
local ssao_sys  = ecs.system "ssao_system"
if not setting:get "graphic/ao/enable" then
    return
end

local mathpkg   = import_package "ant.math"
local mu, mc    = mathpkg.util, mathpkg.constant

local sampler   = import_package "ant.render.core".sampler

local hwi       = import_package "ant.hwi"
local fbmgr     = require "framebuffer_mgr"

local math3d    = require "math3d"

local util      = ecs.require "postprocess.util"

local icompute  = ecs.require "ant.render|compute.compute"
local imaterial = ecs.require "ant.asset|material"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local iviewport = ecs.require "ant.render|viewport.state"

local ENABLE_BENT_NORMAL<const>         = setting:get "graphic/ao/bent_normal"
local SSAO_MATERIAL<const>              = ENABLE_BENT_NORMAL and "/pkg/ant.resources/materials/postprocess/ssao_bentnormal.material" or "/pkg/ant.resources/materials/postprocess/ssao.material"
local BILATERAL_FILTER_MATERIAL<const>  = ENABLE_BENT_NORMAL and "/pkg/ant.resources/materials/postprocess/bilateral_filter_bentnormal.material" or "/pkg/ant.resources/materials/postprocess/bilateral_filter.material"

local SAMPLE_CONFIG<const> = {
    low = {
        sample_count = 3,
        spiral_turns = 1,
        bilateral_filter_raidus = 3,
    },
    medium = {
        sample_count = 5,
        spiral_turns = 2,
        bilateral_filter_raidus = 4,
    },
    high = {
        sample_count = 7,
        spiral_turns = 3,
        bilateral_filter_raidus = 6,
    }
}

local HOWTO_SAMPLE<const> = SAMPLE_CONFIG[setting:get "graphic/ao/quality"]

local ssao_configs = {
    sample_count = HOWTO_SAMPLE.sample_count,
    spiral_turns = HOWTO_SAMPLE.spiral_turns,

    --TODO: need push to ao_setting
    --screen space cone trace
    ssct                        = {
        enable                  = true,
        light_cone              = 1.0,          -- full cone angle in radian, between 0 and pi/2
        shadow_distance         = 0.3,          -- how far shadows can be cast
        contact_distance_max    = 1.0,          -- max distance for contact
        --TODO: need fix cone tracing bug
        intensity               = 0,
        --intensity               = 0.8,          -- intensity
        lightdir                = math3d.ref(math3d.vector(0, 1, 0)),  --light direction
        depth_bias              = 0.01,         -- depth bias in world units (mitigate self shadowing)
        depth_slope_bias        = 0.01,         -- depth slope bias (mitigate self shadowing)
        sample_count            = 4,            -- tracing sample count, between 1 and 255
        ray_count               = 1,            -- # of rays to trace, between 1 and 255
    }
}

do
    ssao_configs.radius = setting:get "graphic/ao/radius"
    ssao_configs.min_horizon_angle = setting:get "graphic/ao/min_horizon_angle"
    ssao_configs.power = setting:get "graphic/ao/min_horizon_angle"
    ssao_configs.intensity = setting:get "graphic/ao/intensity"
    ssao_configs.bilateral_threshold = setting:get "graphic/ao/bilateral_threshold"
    ssao_configs.bias = setting:get "graphic/ao/bias"
    ssao_configs.resolution = setting:get "graphic/ao/resolution"

    ssao_configs.inv_radius_squared             = 1.0/(ssao_configs.radius * ssao_configs.radius)
    ssao_configs.min_horizon_angle_sine_squared = math.sin(ssao_configs.min_horizon_angle) ^ 2.0

    local peak = 0.1 * ssao_configs.radius
    ssao_configs.peak2 = peak * peak

    ssao_configs.visible_power = ssao_configs.power * 2.0

    local TAU<const> = math.pi * 2.0
    ssao_configs.ssao_intentsity = ssao_configs.intensity * (TAU * peak)
    ssao_configs.intensity_pre_sample = ssao_configs.ssao_intentsity / ssao_configs.sample_count

    ssao_configs.inv_sample_count = 1.0 / (ssao_configs.sample_count - 0.5)

    ssao_configs.edge_distance = 1.0 / ssao_configs.bilateral_threshold

    local inc = ssao_configs.inv_sample_count * ssao_configs.spiral_turns * TAU
    ssao_configs.sin_inc, ssao_configs.cos_inc = math.sin(inc), math.cos(inc)

    --ssct
    local ssct = ssao_configs.ssct
    ssct.tan_cone_angle            = math.tan(ssao_configs.ssct.light_cone*0.5)
    ssct.inv_contact_distance_max  = 1.0 / ssct.contact_distance_max
end

local bilateral_config = {
    kernel_radius = HOWTO_SAMPLE.bilateral_filter_raidus,
    std_deviation = 4.0,
    bilateral_threshold = ssao_configs.bilateral_threshold,
}

local KERNEL_MAX_RADIUS_SIZE<const> = 8

local function generate_gaussian_kernels(radius, std_dev)
    local kernels = {{0, 0, 0, 0}, {0, 0, 0, 0}}
    assert(KERNEL_MAX_RADIUS_SIZE // 4 <= #kernels)
    radius = math.min(KERNEL_MAX_RADIUS_SIZE, radius)
    for i=1, radius do
        local x = i-1
        local kidx = (x // 4)+1
        local vidx = (x %  4)+1
        local k = kernels[kidx]
        k[vidx] = math.exp(-(x * x) / (2.0 * std_dev * std_dev))
    end
    return math3d.ref(math3d.array_vector(kernels)), radius
end

local KERNELS, KERNELS_COUNT = generate_gaussian_kernels(bilateral_config.kernel_radius, bilateral_config.std_deviation)

local function update_bilateral_filter_kernels(material)
    material.u_bilateral_kernels = KERNELS
end

function ssao_sys:init()
    icompute.create_compute_entity("ssao_dispatcher", SSAO_MATERIAL, {0, 0, 1})
    icompute.create_compute_entity("bilateral_filter_dispatcher", BILATERAL_FILTER_MATERIAL, {0, 0, 1})
end

local ssao_viewid<const> = hwi.viewid_get "ssao"

local function create_rbidx(ww, hh)
    local rb_flags = sampler{
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
        RT="RT_ON",
        BLIT="BLIT_COMPUTEWRITE",
    }

    local numlayers = ENABLE_BENT_NORMAL and 2 or 1
    return fbmgr.create_rb{w=ww, h=hh, layers=numlayers, format="RGBA8", flags=rb_flags}
end

local function update_ao_properties(material)
    material.u_ssao_param = math3d.vector(
        ssao_configs.visible_power,
        ssao_configs.cos_inc, ssao_configs.sin_inc,
        ssao_configs.edge_distance)

    material.u_ssao_param2 = math3d.vector(
        ssao_configs.sample_count, ssao_configs.inv_sample_count,
        ssao_configs.intensity_pre_sample, ssao_configs.bias)

    material.u_ssao_param3 = math3d.vector(
        ssao_configs.inv_radius_squared,
        ssao_configs.min_horizon_angle_sine_squared,
        ssao_configs.peak2,
        ssao_configs.spiral_turns)
end

local function update_ssct_properties(material)
    --screen space cone trace
    local ssct = ssao_configs.ssct
    material.u_ssct_param2 = math3d.vector(
        ssct.tan_cone_angle,
        ssct.intensity,
        ssct.inv_contact_distance_max,
        ssct.shadow_distance)

    material.u_ssct_param3 = math3d.vector(
        ssct.sample_count,
        ssct.ray_count,
        ssct.depth_bias,
        ssct.depth_slope_bias)
end

function ssao_sys:init_world()
    local vr = mu.calc_viewrect(iviewport.viewrect, ssao_configs.resolution)
    local rbidx = create_rbidx(vr.w, vr.h)

    local aod = w:first "ssao_dispatcher dispatch:in"
    local aod_dis = aod.dispatch
    aod_dis.rb_idx = rbidx
    imaterial.system_attrib_update("s_ssao", fbmgr.get_rb(rbidx).handle)

    update_ao_properties(aod_dis.material)
    update_ssct_properties(aod_dis.material)

    local bfd = w:first "bilateral_filter_dispatcher dispatch:in"
    bfd.dispatch.rb_idx = create_rbidx(vr.w, vr.h)
    update_bilateral_filter_kernels(bfd.dispatch.material)
end

local texmatrix<const> = mu.calc_texture_matrix()

local function calc_ssao_config(camera, aobuf_w, aobuf_h, depthlevel)
    --calc projection scale
    ssao_configs.projection_scale = util.projection_scale(aobuf_w, aobuf_h, camera.projmat)
    ssao_configs.projection_scale_radius = ssao_configs.projection_scale * ssao_configs.radius
    ssao_configs.max_level = depthlevel - 1
end

local function update_ao_frame_properties(dispatcher, ce)
    local dq = w:first "pre_depth_queue render_target:in"
    local m = dispatcher.material
    m.s_depth = fbmgr.get_depth(dq.render_target.fb_idx).handle

    local rb = fbmgr.get_rb(dispatcher.rb_idx)
    m.s_ssao_result = rb.handle

    local aobuf_w, aobuf_h = rb.w, rb.h
    local depthlevel = 1

    local camera = ce.camera
    local projmat = camera.projmat

    calc_ssao_config(camera, aobuf_w, aobuf_h, depthlevel)

    m.u_ssao_param4 = math3d.vector(
        1.0/rb.w, 1.0/rb.h, ssao_configs.max_level,
        ssao_configs.projection_scale_radius)

    local directional_light = w:first "directional_light scene:in"
    local lightdir = directional_light and iom.get_direction(directional_light) or mc.ZAXIS
    lightdir = math3d.normalize(math3d.inverse(math3d.transform(camera.viewmat, lightdir, 0)))
    local lx, ly, lz = math3d.index(lightdir, 1, 2, 3)
    m.u_ssct_param = math3d.vector(lx, ly, lz, ssao_configs.projection_scale)

    --screen matrix
    do
        local baismatrix = math3d.mul(math3d.matrix(
            aobuf_w, 0.0, 0.0, 0.0,
            0.0, aobuf_h, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            aobuf_w, aobuf_h, 0.0, 1.0
        ), texmatrix)
        m.u_ssct_screen_from_view_mat = math3d.mul(baismatrix, projmat)
    end
end

local function update_bilateral_filter_frame_properties(material, inputhandle, outputhandle, offset, inv_camera_far_with_bilateral_threshold)
    material.s_ssao_result = inputhandle
    material.s_filter_result = outputhandle
    material.u_bilateral_param = math3d.vector(offset[1], offset[2], KERNELS_COUNT, inv_camera_far_with_bilateral_threshold)
end

local mqvr_mb = world:sub{"view_rect_changed", "main_queue"}

function ssao_sys:data_changed()
    for _, _, vr in mqvr_mb:unpack() do
        local aod = w:first "ssao_dispatcher dispatch:in"
        local bfd = w:first "bilateral_filter_dispatcher dispatch:in"
        local new_vr = mu.calc_viewrect(vr, ssao_configs.resolution)

        fbmgr.resize_rb(aod.dispatch.rb_idx, new_vr.w, new_vr.h)
        imaterial.system_attrib_update("s_ssao", fbmgr.get_rb(aod.dispatch.rb_idx).handle)

        fbmgr.resize_rb(bfd.dispatch.rb_idx, new_vr.w, new_vr.h)

        icompute.calc_dispatch_size_2d(new_vr.w, new_vr.h, aod.dispatch.size)
        icompute.calc_dispatch_size_2d(new_vr.w, new_vr.h, bfd.dispatch.size)
    end
end

function ssao_sys:build_ssao()
    local aod = w:first "ssao_dispatcher dispatch:in"
    local mq = w:first "main_queue camera_ref:in"
    local ce = world:entity(mq.camera_ref, "camera:in")
    local d = aod.dispatch
    update_ao_frame_properties(d, ce)

    icompute.dispatch(ssao_viewid, d)
end

function ssao_sys:bilateral_filter()
    local mq = w:first "main_queue camera_ref:in"
    local ce = world:entity(mq.camera_ref, "camera:in")
    local inv_camera_far_with_bilateral_threshold<const> = ce.camera.frustum.f / bilateral_config.bilateral_threshold
    
    local bfd = w:first "bilateral_filter_dispatcher dispatch:in"

    local sd = w:first "ssao_dispatcher dispatch:in"
    local inputrb = fbmgr.get_rb(sd.dispatch.rb_idx)
    local inputhandle = inputrb.handle
    local outputrb = fbmgr.get_rb(bfd.dispatch.rb_idx)
    local outputhandle = outputrb.handle

    assert(outputrb.w == inputrb.w and outputrb.h == inputrb.h)
    local bf_dis = bfd.dispatch
    local bfdmaterial = bf_dis.material
    update_bilateral_filter_frame_properties(bfdmaterial, inputhandle, outputhandle, {1.0/inputrb.w, 0.0}, inv_camera_far_with_bilateral_threshold)
    icompute.dispatch(ssao_viewid, bf_dis)

    update_bilateral_filter_frame_properties(bfdmaterial, outputhandle, inputhandle, {0.0, 1.0/inputrb.h}, inv_camera_far_with_bilateral_threshold)
    icompute.dispatch(ssao_viewid, bf_dis)

end
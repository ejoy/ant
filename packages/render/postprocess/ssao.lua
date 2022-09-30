local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"

local math3d    = require "math3d"

local util      = ecs.require "postprocess.util"

local irender   = ecs.import.interface "ant.render|irender"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"

local ssao_sys  = ecs.system "ssao_system"

function ssao_sys:init()
    util.create_quad_drawer("ssao_drawer", "/pkg/ant.resources/materials/postprocess/ssao.material")
end

local ssao_viewid<const> = viewidmgr.get "ssao"
local bilateral_filter_viewid<const>, bilateral_filter_count<const> = viewidmgr.get_range "bilateral_filter"
assert(bilateral_filter_count == 2, "need 2 pass blur: horizontal and vertical")
local bilateral_filter_horizontal_viewid<const>, bilateral_filter_vertical_viewid<const> = bilateral_filter_viewid, bilateral_filter_viewid+1

local ENABLE_BENT_NORMAL<const> = false

local function create_framebuffer(ww, hh)
    local rb_flags = sampler{
        MIN="POINT",
        MAG="POINT",
        U="CLAMP",
        V="CLAMP",
        RT="RT_ON",
    }

    local function create_rb() return fbmgr.create_rb{w=ww, h=hh, layers=1, format="RGBA8", flags=rb_flags} end

    local rb1 = create_rb()

    if ENABLE_BENT_NORMAL then
        return fbmgr.create(
            {rbidx=rb1},
            {rbidx=create_rb()}
        )

    end
    return fbmgr.create{rbidx=rb1}
end

function ssao_sys:init_world()
    local vr = mu.copy_viewrect(world.args.viewport)

    local fbidx = create_framebuffer(vr.w, vr.h)
    util.create_queue(ssao_viewid, vr, fbidx, "ssao_queue", "ssao_queue")

    --TODO: use compute shader to resolve msaa depth to normal depth
    local sqd = w:first("scene_depth_queue visible?out")
    sqd.visible = true
    w:submit(sqd)

    local fbidx_blur = create_framebuffer(vr.w, vr.h)
    util.create_queue(bilateral_filter_horizontal_viewid, mu.copy_viewrect(vr), fbidx_blur, "bilateral_filter_horizontal_queue", "bilateral_filter_horizontal_queue")
    util.create_queue(bilateral_filter_vertical_viewid, mu.copy_viewrect(vr), fbidx, "bilateral_filter_vertical_queue", "bilateral_filter_vertical_queue")
end

local texmatrix<const> = mu.calc_texture_matrix()

local ssao_configs = {
    enabled                     = false,    -- enables or disables screen-space ambient occlusion
    enableBentNormals           = false,    -- enables bent normals computation from AO, and specular AO

    radius                      = 0.3,      -- Ambient Occlusion radius in meters, between 0 and ~10.
    power                       = 1.0,      -- Controls ambient occlusion's contrast. Must be positive.
    bias                        = 0.0005,   -- Self-occlusion bias in meters. Use to avoid self-occlusion. Between 0 and a few mm.
    resolution                  = 0.5,      -- How each dimension of the AO buffer is scaled. Must be either 0.5 or 1.0.
    intensity                   = 1.0,      -- Strength of the Ambient Occlusion effect.
    bilateral_threshold         = 0.05,     -- depth distance that constitute an edge for filtering
    quality                     = "LOW",    -- affects # of samples used for AO.
    low_pass_filter             = "MEDIUM", -- affects AO smoothness
    upsampling                  = "LOW",    -- affects AO buffer upsampling quality
    min_horizon_angle           = 0.0,      -- min angle in radian to consider

    --
    sample_count                = 7,
    spiral_turns                = 3,
    --

    --screen space cone trace
    ssct                        = {
        enable                  = true,
        light_cone              = 1.0,          -- full cone angle in radian, between 0 and pi/2
        shadow_distance         = 0.3,          -- how far shadows can be cast
        contact_distance_max    = 1.0,          -- max distance for contact
        intensity               = 0.8,          -- intensity
        lightdir                = math3d.ref(math3d.vector(0, 1, 0)),  --light direction
        depth_bias              = 0.01,         -- depth bias in world units (mitigate self shadowing)
        depth_slope_bias        = 0.01,         -- depth slope bias (mitigate self shadowing)
        sample_count            = 4,            -- tracing sample count, between 1 and 255
        ray_count               = 1,            -- # of rays to trace, between 1 and 255
    },
}

local function update_config(camera, lightdir, depthwidth, depthheight, depthdepth)
    ssao_configs.inv_radius_squared             = 1.0/(ssao_configs.radius * ssao_configs.radius)
    ssao_configs.min_horizon_angle_sine_squared = math.sin(ssao_configs.min_horizon_angle) ^ 2.0

    --calc projection scale
    ssao_configs.projection_scale = util.projection_scale(depthwidth, depthheight, camera.projmat)
    ssao_configs.projection_scale_radius = ssao_configs.projection_scale * ssao_configs.radius

    local peak = 0.1 * ssao_configs.radius
    ssao_configs.peak2 = peak * peak

    ssao_configs.visible_power = ssao_configs.power * 2.0

    local TAU<const> = math.pi * 2.0
    ssao_configs.ssao_intentsity = ssao_configs.intensity * (TAU * peak)
    ssao_configs.intensity_pre_sample = ssao_configs.ssao_intentsity / ssao_configs.sample_count

    ssao_configs.max_level = depthdepth - 1

    ssao_configs.inv_sample_count = 1.0 / (ssao_configs.sample_count - 0.5)

    
    local inc = ssao_configs.inv_sample_count * ssao_configs.spiral_turns * TAU
    ssao_configs.sin_inc, ssao_configs.cos_inc = math.sin(inc), math.cos(inc)

    --ssct
    local ssct = ssao_configs.ssct
    ssct.tan_cone_angle            = math.tan(ssao_configs.ssct.light_cone*0.5)
    ssct.inv_contact_distance_max  = 1.0 / ssct.contact_distance_max
    ssct.lightdir.v                = math3d.normalize(math3d.inverse(math3d.transform(camera.viewmat, lightdir, 0)))
end

local function update_properties(drawer, ce)
    --TODO: use nomral scene depth buffer
    local sdq = w:first("scene_depth_queue render_target:in")
    imaterial.set_property(drawer, "s_scene_depth", fbmgr.get_depth(sdq.render_target.fb_idx).handle)

    local vr = sdq.render_target.view_rect
    local depthwidth, depthheight, depthdepth = vr.w, vr.h, 1
    local camera = ce.camera
    local projmat = camera.projmat

    local directional_light = w:first("directional_light scene:in")
    local lightdir = iom.get_direction(directional_light)
    update_config(camera, lightdir, depthwidth, depthheight, depthdepth)

    imaterial.set_property(drawer, "u_ssao_param", math3d.vector(
        ssao_configs.visible_power,
        ssao_configs.cos_inc, ssao_configs.sin_inc,
        ssao_configs.projection_scale_radius
    ))

    imaterial.set_property(drawer, "u_ssao_param2", math3d.vector(
        ssao_configs.sample_count, ssao_configs.inv_sample_count,
        ssao_configs.intensity_pre_sample, ssao_configs.bias
    ))

    imaterial.set_property(drawer, "u_ssao_param3", math3d.vector(
        ssao_configs.inv_radius_squared,
        ssao_configs.min_horizon_angle_sine_squared,
        ssao_configs.peak2,
        ssao_configs.spiral_turns
    ))

    imaterial.set_property(drawer, "u_ssao_param4", math3d.vector(
        ssao_configs.max_level, 0.0, 0.0, 0.0
    ))

    --screen space cone trace
    local ssct = ssao_configs.ssct
    local lx, ly, lz = math3d.index(ssct.lightdir, 1, 2, 3)
    imaterial.set_property(drawer, "u_ssct_param", math3d.vector(
        lx, ly, lz,
        ssct.intensity
    ))

    imaterial.set_property(drawer, "u_ssct_param2", math3d.vector(
        ssct.tan_cone_angle,
        ssao_configs.projection_scale,
        ssct.inv_contact_distance_max,
        ssct.shadow_distance
    ))

    imaterial.set_property(drawer, "u_ssct_param3", math3d.vector(
        ssct.sample_count,
        ssct.ray_count,
        ssct.depth_bias,
        ssct.depth_slope_bias
    ))
    --screen matrix
    do
        local baismatrix = math3d.mul(math3d.matrix(
            depthwidth, 0.0, 0.0, 0.0,
            0.0, depthheight, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            depthwidth, depthheight, 0.0, 1.0
        ), texmatrix)

        local screenmatrix = math3d.mul(baismatrix, projmat)
        imaterial.set_property(drawer, "u_ssct_screen_from_view_mat", screenmatrix)
    end
end

local bilateral_config = {
    kernel_size = 16,
    std_deviation = 1.0,
    bilateral_threshold = 0.0065,
}

local function update_bilateral_filter_properties(drawer, sao_handle, bn_handle, kernels, offset, camera_far)
    local sample_radius_count<const> = #kernels
    imaterial.set_property(drawer, "s_sao", sao_handle, bn_handle)
    imaterial.set_property(drawer, "u_bilateral_weight", kernels)
    imaterial.set_property(drawer, "u_bilateral_param", 
        math3d.vector(offset[1], offset[2], sample_radius_count, camera_far/bilateral_config.bilateral_threshold))
end

local kernel_max_size<const> = 16

local function gaussian_sample_radius_count(kernelsize)
    return math.min(kernel_max_size, (kernelsize+1)/2);
end

local function generate_gaussian_kernels(kernelsize, std_dev)
    local count = gaussian_sample_radius_count(kernelsize)
    local kernels = {}
    for i=1, count do
        local x = i-1
        kernels[i] = math.exp(-(x * x) / (2.0 * std_dev * std_dev))
    end
    return kernels
end

local function submit_bilateral_filter(drawer, viewid, rt, kernels, offset, camerafar)
    local fb = fbmgr.get(rt.fb_idx)
    local ao_handle, bn_handle = fbmgr.get_rb(fb[1]).handle, fbmgr.get_rb(fb[2]).handle

    local vr = rt.view_rect
    update_bilateral_filter_properties(drawer, ao_handle, bn_handle, kernels, {offset[1]/vr.w, offset[2]/vr.h}, camerafar)
    irender.draw(viewid, "ssao_drawer")
end

function ssao_sys:ssao()
    local drawer = w:first("ssao_drawer filter_material:in")
    local mq = w:first("main_queue camera_ref:in")
    local ce = w:entity(mq.camera_ref, "camera:in")
    update_properties(drawer, ce)

    irender.draw(ssao_viewid, "ssao_drawer")

    -- take bilateral filter
    local kernels = generate_gaussian_kernels(bilateral_config.kernel_size, bilateral_config.std_deviation)
    local camera_far<const> = ce.frustum.f
    local aoqueue = w:first("ssao_queue render_target:in")
    submit_bilateral_filter(kernels, bilateral_filter_horizontal_viewid, aoqueue.render_target, kernels, {1.0, 0.0}, camera_far)

    local bf_queue = w:first("bilateral_filter_horizontal_queue render_target:in")
    submit_bilateral_filter(drawer, bilateral_filter_vertical_viewid, bf_queue.render_target, kernels, {0.0, 1.0}, camera_far)

    -- output result
    local pp = w:first("postprocess postprocess_input:in")
    local ppi = pp.postprocess_input
    local fb = fbmgr.get(aoqueue.render_target.fb_idx)
    ppi.ssao_handle = fbmgr.get_rb(fb[1]).handle
    ppi.bent_normal_handle = fbmgr.get_rb(fb[2]).handle
end
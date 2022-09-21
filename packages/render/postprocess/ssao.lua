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
local ssao_blur_viewid<const>, ssao_blur_count<const> = viewidmgr.get_range "ssao_blur"
assert(ssao_blur_count == 2, "need 2 pass blur: horizontal and vertical")
local ssao_hblur_viewid<const>, ssao_vblur_viewid<const> = ssao_blur_viewid, ssao_blur_viewid+1

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
    local vp = world.args.viewport
    local vr = {x=vp.x, y=vp.y, w=vp.w, h=vp.h}

    local fbidx = create_framebuffer(vr.w, vr.h)
    util.create_queue(ssao_viewid, vr, fbidx, "ssao_queue", "ssao_queue")

    local sqd = w:first("scene_depth_queue visible?out")
    sqd.visible = true
    w:submit(sqd)
    --TODO: blur
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
    spiral_turns                = 6,
    --

    --screen space cone trace
    ssct                        = {
        enable                  = true,
        shadow_distance         = 1.0,          -- full cone angle in radian, between 0 and pi/2
        light_cone              = 0.3,          -- how far shadows can be cast
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
    do
        -- estimate of the size in pixel of a 1m tall/wide object viewed from 1m away (i.e. at z=1)
        local projmat_c1, projmat_c2 = math3d.index(camera.projmat, 1, 2)
        local c1x, c2y = math3d.index(projmat_c1, 1), math3d.index(projmat_c2, 2)
        ssao_configs.projection_scale = math.min(c1x*0.5*depthwidth, c2y*0.5*depthheight)
    end

    ssao_configs.projection_scale_radius = ssao_configs.projection_scale * ssao_configs.radius

    local peak = 0.1 * ssao_configs.radius
    ssao_configs.peak2 = peak * peak

    ssao_configs.visible_power = ssao_configs.power * ssao_configs.power

    ssao_configs.intensity_pre_sample = ssao_configs.intensity / ssao_configs.sample_count

    ssao_configs.max_level = depthdepth - 1

    ssao_configs.inv_sample_count = 1.0 / (ssao_configs.sample_count - 0.5)

    local TAU<const> = math.pi * 2.0
    local inc = ssao_configs.inv_sample_count * ssao_configs.spiral_turns * TAU
    ssao_configs.sin_inc, ssao_configs.cos_inc = math.sin(inc), math.cos(inc)

    --ssct
    local ssct = ssao_configs.ssct
    ssct.tan_cone_angle            = math.tan(ssao_configs.ssct.light_cone*0.5)
    ssct.inv_contact_distance_max  = 1.0 / ssct.contact_distance_max
    ssct.lightdir.v                = math3d.transform(camera.viewmat, lightdir, 0)
end


local function update_properties()
    local d = w:first("ssao_drawer filter_material:in")

    local sdq = w:first("scene_depth_queue render_target:in")
    imaterial.set_property(d, "s_scene_depth", fbmgr.get_depth(sdq.render_target.fb_idx).handle)

    local mq = w:first("main_queue render_target:in camera_ref:in")
    local vr = mq.render_target.view_rect
    local depthwidth, depthheight, depthdepth = vr.w, vr.h, 1
    local ce = w:entity(mq.camera_ref, "camera:in")
    local camera = ce.camera
    local projmat = camera.projmat

    local directional_light = w:first("directional_light scene:in")
    local lightdir = iom.get_direction(directional_light)
    update_config(camera, lightdir, depthwidth, depthheight, depthdepth)

    imaterial.set_property(d, "u_ssao_param", math3d.vector(
        ssao_configs.visible_power,
        ssao_configs.cos_inc, ssao_configs.sin_inc,
        ssao_configs.projection_scale_radius
    ))

    imaterial.set_property(d, "u_ssao_param2", math3d.vector(
        ssao_configs.sample_count, ssao_configs.inv_sample_count,
        ssao_configs.intensity_pre_sample, ssao_configs.bias
    ))

    imaterial.set_property(d, "u_ssao_param3", math3d.vector(
        ssao_configs.inv_radius_squared,
        ssao_configs.min_horizon_angle_sine_squared,
        ssao_configs.peak2,
        ssao_configs.spiral_turns
    ))

    imaterial.set_property(d, "u_ssao_param4", math3d.vector(
        ssao_configs.max_level, 0.0, 0.0, 0.0
    ))

    --screen space cone trace
    local ssct = ssao_configs.ssct
    local lx, ly, lz = math3d.index(ssct.lightdir, 1, 2, 3)
    imaterial.set_property(d, "u_ssct_param", math3d.vector(
        lx, ly, lz,
        ssct.intensity
    ))

    imaterial.set_property(d, "u_ssct_param2", math3d.vector(
        ssct.tan_cone_angle,
        ssao_configs.projection_scale,
        ssct.inv_contact_distance_max,
        ssct.shadow_distance
    ))

    imaterial.set_property(d, "u_ssct_param3", math3d.vector(
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
        imaterial.set_property(d, "u_ssct_screen_from_view_mat", screenmatrix)
    end
end

function ssao_sys:ssao()
    update_properties()

    irender.draw(ssao_viewid, "ssao_drawer")
end
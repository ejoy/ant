local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"

local math3d    = require "math3d"

local util      = ecs.require "util"

local irender   = ecs.import.interface "ant.render|irender"
local imaterial = ecs.import.interface "ant.asset|imaterial"
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

    local function create_rb()
        fbmgr.create_rb{
            w=ww, h=hh, layers=1, format="RGBA8", flags=rb_flags
        }
    end

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

    --TODO: blur
end

local texmatrix<const> = mu.calc_texture_matrix()

local ssao_disk_radius = 1.0

local ssao_configs = {
    radius = 1.0, 
    minHorizonAngleRad = 0.0,
    projectionScale = 1.0,
    bias = 1.0,
    power = 2.0,
    sample_count = 7,
    level_count = 0,
    spiralTurns = 4,
    ssct = {
        shadowDistance = 1.0,
        lightConeRad = 1.0,
        contactDistanceMax = 1.0,
    }
}

local function update_properties()
--[[
uniform vec4 u_ssao_param;
#define u_ssao_visiblity_power          u_ssao_param.x
#define u_ssao_angle_inc_sin            u_ssao_param.y
#define u_ssao_angle_inc_cos            u_ssao_param.z
#define u_ssao_projection_scale_radius  u_ssao_param.w

uniform vec4 u_ssao_param2;
#define u_ssao_sample_count             u_ssao_param2.x
#define u_ssao_inv_sample_count         u_ssao_param2.y
#define u_ssao_intensity                u_ssao_param2.z
#define u_ssao_bias                     u_ssao_param2.w

uniform vec4 u_ssao_param3;
#define u_ssao_inv_radius_squared               u_ssao_param3.x
#define u_ssao_min_horizon_angle_sine_squared   u_ssao_param3.y
#define u_ssao_peak2                            u_ssao_param3.z
#define u_ssao_spiral_turns                     u_ssao_param4.w

uniform vec4 u_ssao_param4;
#define u_ssao_max_level                        u_ssao_param4.x


// ssct
uniform vec4 u_ssct_param;
#define u_ssct_lightdirVS                       u_ssct_param.xyz
#define u_ssct_shadow_distance                  u_ssct_param.w

uniform vec4 u_ssct_param2;
#define u_ssct_cone_angle_tangeant              u_ssct_param2.x
#define u_ssct_contact_distance_max_inv         u_ssct_param2.y
#define u_ssct_projection_scale                 u_ssct_param2.zw

uniform vec4 u_ssct_param3;
#define u_ssct_intensity                        u_ssct_param3.x
#define u_ssct_sample_count                     u_ssct_param3.y
#define u_ssct_depth_bias                       u_ssct_param3.z
#define u_ssct_slope_scaled_depth_bias          u_ssct_param3.w

uniform vec4 u_ssct_param4;
#define u_ssct_ray_count                        u_ssct_param4.x

uniform mat4 u_ssct_screen_from_view_mat;
]]

-- const mat4 screenFromClipMatrix{ mat4::row_major_init{
--     0.5 * desc.width, 0.0, 0.0, 0.5 * desc.width,
--     0.0, 0.5 * desc.height, 0.0, 0.5 * desc.height,
--     0.0, 0.0, 0.5, 0.5,
--     0.0, 0.0, 0.0, 1.0
-- }};
    local d<close> = w:first("ssao_drawer filter_material:in")
    local dm = d.filter_material.main_queue

    local pp = w:first("postprocess postprocess_input:in")
    dm.s_scene_depth = pp.postprocess_input.scene_depth_handle

    local mq = w:first("main_queue render_target:in camera_ref:in")
    local vr = mq.render_target.view_rect
    local depthwidth, depthheight = vr.w, vr.h

    --screen matrix
    local ce = w:entity(mq.camera_ref, "camera:in")

    local baismatrix = math3d.mul(math3d.matrix(
        depthwidth, 0.0, 0.0, 0.0,
        0.0, depthheight, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        depthwidth, depthheight, 0.0, 1.0
    ), texmatrix)

    local screenmatrix = math3d.mul(baismatrix, ce.projmat)
    imaterial.set_property(d, "u_ssct_screen_from_view_mat", screenmatrix)


end

function ssao_sys:ssao()
    update_properties()

    irender.draw(ssao_viewid, "ssao_drawer")
end
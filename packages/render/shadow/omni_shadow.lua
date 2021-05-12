local ecs = ...
local world = ecs.world

local fbmgr = require "framebuffer_mgr"
local viewidmgr = require "viewid_mgr"

local samplerutil = require "sampler"
local shadowcommon = require "shadow.common"
local math3d = require "math3d"

local iom = world:interface "ant.objcontroller|obj_motion"
local ilight = world:interface "ant.render|ilight"
local icamera = world:interface "ant.camera|camera"

local function get_render_buffers(width, height)
    return fbmgr.create_rb{
        format = "D32F",
        w=width,
        h=height,
        layers=1,
        flags=samplerutil.sampler_flag{
            RT="RT_ON",
            MIN="LINEAR",
            MAG="LINEAR",
            U="CLAMP",
            V="CLAMP",
            COMPARE="COMPARE_LEQUAL",
            BOARD_COLOR="0",
        },
    }
end

local function crop_matrix(s, offset)
    return math3d.mul(math3d.matrix(
        s[1], 0.0, 0.0, 0.0,
        0.0, s[2], 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        offset[1], offset[2], 0.0, 0.0
    ), shadowcommon.sm_bias_matrix)
end

local def_sm_size<const> = 512
local half_def_sm_size<const> = def_sm_size * 0.5
local TetrahedronFaces = {
    Green = {
        rotation = math3d.ref(math3d.quaternion(math.rad( 27.36780516), math.rad(  0.0), math.rad(0.0))),
        view_rect = {x=0, y=0, w=half_def_sm_size, h=half_def_sm_size},
        crop_matrix = crop_matrix({0.5, 0.5}, {0.0, 0.0}),
        center_view = math3d.ref(math3d.vector()),
    },
    Yellow = {
        rotation = math3d.ref(math3d.quaternion(math.rad( 27.36780516), math.rad(180.0), math.rad(0.0))),
        view_rect = {x=half_def_sm_size, y=0, w=half_def_sm_size, h=half_def_sm_size},
        crop_matrix = crop_matrix({0.5, 0.5}, {0.5, 0.0}),
        center_view = math3d.ref(math3d.vector()),
    },
    Blue = {
        rotation = math3d.ref(math3d.quaternion(math.rad(-27.36780516), math.rad(-90.0), math.rad(0.0))),
        view_rect = {x=0, y=half_def_sm_size, w=half_def_sm_size, h=half_def_sm_size},
        crop_matrix = crop_matrix({0.5, 0.5}, {0.0, 0.5}),
        center_view = math3d.ref(math3d.vector()),
    },
    Red = {
        rotation = math3d.ref(math3d.quaternion(math.rad(-27.36780516), math.rad( 90.0), math.rad(0.0))),
        view_rect = {x=half_def_sm_size, y=half_def_sm_size, w=half_def_sm_size, h=half_def_sm_size},
        crop_matrix = crop_matrix({0.5, 0.5}, {0.5, 0.5}),
        center_view = math3d.ref(math3d.vector()),
    }
};

local fovx_adjust<const>, fovy_adjust<const> = 0.0, 0.0
local fovx<const> = 143.98570868 + 7.8 + fovx_adjust
local fovy<const> = 125.26438968 + 3.0 + fovx_adjust

local aspect<const> = math.tan(math.rad(fovx*0.5) )/math.tan(math.rad(fovy*0.5))


local omni_setting = {
    size = def_sm_size,
    fb_idx = fbmgr.create(get_render_buffers(def_sm_size))
}

local ios = world:interface "iomni_shadow"

function ios.setting()
    return omni_setting
end

function ios.create(point_eid)
    local eids = {}
    local range = ilight.range(point_eid)
    local pos = iom.get_position(point_eid)
    for k, t in pairs(TetrahedronFaces) do
        local name = "omni_" .. k
        local worldmat = math3d.matrix{r=t.rotation}
        local updir, viewdir = math3d.index(worldmat, 2, 3)
        local cameraeid = icamera.create {
                updir 	= updir,
                viewdir = viewdir,
                eyepos 	= pos,
                frustum = {
                    fov = fovy,
                    aspect = aspect,
                    n = 1, f = range
                },
                name = "camera_" .. name
            }

        eids[k] = world:create_entity{
            policy = {
                "ant.render|omni_shadow",
                "ant.render|render_queue",
                "ant.general|name",
            },
            data = {
                camera_eid = cameraeid,
                render_target = {
                    view_rect = k.view_rect,
                    view_mode = "s",
                    viewid = viewidmgr.get(name),
                    fb_idx = omni_setting.fb_idx,
                },
                clear_state = {
					color = 0xffffffff,
					depth = 1,
					stencil = 0,
					clear = "DS",
				},
                primitive_filter = {
                    filter_type = "cast_shadow",
                },
                omni = {
                    name = k,
                },
                visible = false,
                name = name,
            },
        }
    end

    return eids
end


local omni_shadow_sys = ecs.system "omni_shadow_system"

local pl_reg_mb = world:sub{"component_register", "make_shadow"}

function omni_shadow_sys:data_changed()
    for msg in pl_reg_mb.each() do
        local eid = msg[3]

    end
end

function omni_shadow_sys:update_camera()

end
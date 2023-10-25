local ecs = ...
local world = ecs.world
local w = world.w
--[[
    see:
    1. GPU Pro 1 - Shadow Mapping for omnidiectional Light Using Tetrahedron Mapping
    2. Bgfx example 16
    3. GPU Pro 6 - Tile-Based Omnidirectional Shadows

    it's hard to add too mush point light shadow in the scene. first, we should use tetrahedron shadow mapping
    to make the omni shadow in 2d texture, then we need to alloc a large shadowmap, then put every omni shadow
    in that large 2d texture, that time, if we can determine the point light far from us, we should use less
    texture space for then, so we need to alats all the tetrahedron shadow map in that large 2d texture,
    finally, shadow map is generated, in cluster shading, we need to put all the point light shadow info in
    clusters, when render item, we should find that item use how many point light/shadow, and calcuate it's color

    right now, this omni is disable
]]

local INV_Z<const> = true
local INF_F<const> = true
local fbmgr         = require "framebuffer_mgr"
local sampler       = require "sampler"

local hwi           = import_package "ant.hwi"
local mathpkg       = import_package "ant.math"
local mu            = mathpkg.util


local math3d        = require "math3d"

local iom       = ecs.require "ant.objcontroller|obj_motion"
local icamera   = ecs.require "ant.camera|camera"
local ivs       = ecs.require "ant.render|visible_state"
local ilight    = ecs.require "ant.render|light.light"
local ientity   = ecs.require "ant.render|components.entity"

local function get_render_buffers(width, height)
    return fbmgr.create_rb{
        format = "D24S8",
        w=width,
        h=height,
        layers=1,
        flags=sampler{
            RT="RT_ON",
            MIN="LINEAR",
            MAG="LINEAR",
            U="CLAMP",
            V="CLAMP",
            COMPARE="COMPARE_LEQUAL",
            SAMPLE="SAMPLE_STENCIL",
            BOARD_COLOR="0",
        },
    }
end



-- local crop_matrices = {
--     { // D3D: Red, OGL: Blue
--     0.25,   0.0f, 0.0f, 0.0f,
--     0.0, s*0.5f, 0.0f, 0.0f,
--     0.0,   0.0f, 0.5f, 0.0f,
--     0.25,   0.5f, zadd, 1.0f,
-- },
-- { // D3D: Blue, OGL: Red
--     0.25f,   0.0f, 0.0f, 0.0f,
--  0.0f, s*0.5f, 0.0f, 0.0f,
--  0.0f,   0.0f, 0.5f, 0.0f,
--     0.75f,   0.5f, zadd, 1.0f,
-- },
-- { // D3D: Green, OGL: Green
--     0.5f,    0.0f, 0.0f, 0.0f,
--     0.0f, s*0.25f, 0.0f, 0.0f,
--     0.0f,    0.0f, 0.5f, 0.0f,
--     0.5f,   0.75f, zadd, 1.0f,
-- },
-- { // D3D: Yellow, OGL: Yellow
--     0.5f,    0.0f, 0.0f, 0.0f,
--     0.0f, s*0.25f, 0.0f, 0.0f,
--     0.0f,    0.0f, 0.5f, 0.0f,
--     0.5f,   0.25f, zadd, 1.0f,
-- },
-- }

local function crop_matrix(s, offset)
    return math3d.mul(math3d.matrix(
        s[1], 0.0, 0.0, 0.0,
        0.0, s[2], 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        offset[1], offset[2], 0.0, 0.0
    ), mu.calc_texture_matrix())
end

local def_sm_size<const> = 512
local half_def_sm_size<const> = def_sm_size * 0.5

local flipv = math3d.get_origin_bottom_left() and -1.0 or 1.0

local TetrahedronFaces = {
    Green = {
        rotation = math3d.ref(math3d.quaternion{math.rad( 27.36780516), math.rad(  0.0), math.rad(180.0)}),
        view_rect = {x=0, y=0, w=def_sm_size, h=half_def_sm_size},
        crop_matrix = math3d.ref(math3d.matrix(
            0.25,   0.0,    0.0, 0.0,
             0.0, flipv*0.5,0.0, 0.0,
             0.0,   0.0,    0.5, 0.0,
            0.25,   0.5,    0.0, 1.0
        )),
        center_view = math3d.ref(math3d.vector(0.0, -0.57735026, 0.81649661)),
        stencil_ref = 1,
    },
    Yellow = {
        rotation = math3d.ref(math3d.quaternion{math.rad( 27.36780516), math.rad(180.0), math.rad(0.0)}),
        view_rect = {x=0, y=half_def_sm_size, w=def_sm_size, h=half_def_sm_size},
        crop_matrix = math3d.ref(math3d.matrix(
            0.25,   0.0,    0.0, 0.0,
             0.0, flipv*0.5,0.0, 0.0,
             0.0,   0.0,    0.5, 0.0,
            0.75,   0.5,    0.0, 1.0
        )),
        center_view = math3d.ref(math3d.vector(0.0, -0.57735026, -0.81649661)),
        stencil_ref = 1,
    },
    Blue = {
        rotation = math3d.ref(math3d.quaternion{math.rad(-27.36780516), math.rad(-90.0), math.rad(90.0)}),
        view_rect = {x=0, y=0, w=half_def_sm_size, h=def_sm_size},
        crop_matrix = math3d.ref(math3d.matrix(
            0.5,    0.0,    0.0, 0.0,
            0.0, flipv*0.25,0.0, 0.0,
            0.0,    0.0,    0.5, 0.0,
            0.5,   0.75,    0.0, 1.0
        )),
        center_view = math3d.ref(math3d.vector(-0.81649661, 0.57735026, 0.0)),
        stencil_ref = 0,
    },
    Red = {
        rotation = math3d.ref(math3d.quaternion{math.rad(-27.36780516), math.rad( 90.0), math.rad(-90.0)}),
        view_rect = {x=half_def_sm_size, y=0, w=half_def_sm_size, h=def_sm_size},
        crop_matrix = math3d.ref(math3d.matrix(
            0.5,    0.0,    0.0, 0.0,
            0.0, flipv*0.25,0.0, 0.0,
            0.0,    0.0,    0.5, 0.0,
            0.5,   0.25,    0.0, 1.0
        )),
        center_view = math3d.ref(math3d.vector(0.81649661, 0.57735026, 0.0)),
        stencil_ref = 0,
    }
};

local fb_index<const> = fbmgr.create{rbidx=get_render_buffers(def_sm_size, def_sm_size)}

local fovx_adjust<const>, fovy_adjust<const> = 0.0, 0.0
local fovx<const> = 143.98570868 + 7.8 + fovx_adjust
local fovy<const> = 125.26438968 + 3.0 + fovy_adjust

local aspect<const> = math.tan(math.rad(fovx*0.5) )/math.tan(math.rad(fovy*0.5))

local ios = {}

function ios.setting()
    return TetrahedronFaces
end

function ios.fb_index()
    return fb_index
end

local stencil_mesh

local function add_stencil_entity()
    if stencil_mesh == nil then
        local stencil_tri_vertices<const> = {
            0.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            0.5, 0.5, 0.0,
            0.5, 0.5, 0.0,
            1.0, 1.0, 0.0,
            0.0, 1.0, 0.0,
        }
        stencil_mesh = ientity.create_mesh{"p3", stencil_tri_vertices}
    end

    return world:create_entity {
		policy = {
			"ant.render|render",
		},
		data = {
			material	= "/pkg/ant.resources/materials/omni_stencil.material",
			mesh		= stencil_mesh,
			visible_state= "main_view|cast_shadow",
		}
	}
end

function ios.create(point_eid)
    local eids = {}
    local range = ilight.range(point_eid)
    local pos = iom.get_position(point_eid)
    local frustum = {
        fov     = fovy,
        aspect  = aspect,
        n = 0.2,  f = range,
    }

    add_stencil_entity()

    for k, t in pairs(TetrahedronFaces) do
        local queuename = "omni_" .. k
        local worldmat = math3d.matrix{r=t.rotation}
        local updir, viewdir = math3d.index(worldmat, 2, 3)
        local camera_ref = icamera.create {
                updir 	= updir,
                viewdir = viewdir,
                eyepos 	= pos,
                frustum = frustum,
                name = "camera_" .. queuename
            }

        world:create_entity {
            policy = {
                "ant.render|omni_shadow",
                "ant.render|render_queue",
            },
            data = {
                camera_ref = camera_ref,
                render_target = {
                    view_rect = t.view_rect,
                    viewid = hwi.viewid_get(queuename),
                    fb_idx = fb_index,
                },
                clear_state = {
					color = 0xffffffff,
					depth = 0,
					stencil = 0,
					clear = "DS",
				},
                omni = {
                    name = k,
                    light_eid = point_eid,
                    stencil_ref = t.stencil_ref,
                },
                queue_name = queuename,
                visible = false,
                omni_queue = true,
            },
        }
    end

    return eids
end


local omni_shadow_sys = ecs.system "omni_shadow_system"

local pl_reg_mb = world:sub{"component_register", "make_shadow"}
local pl_rm_mbs

function omni_shadow_sys:data_changed()
    for msg in pl_reg_mb:each() do
        local eid = msg[3]
        local e = world[eid]
        if ivs.has_state "visible" and e.make_shadow then
            ios.create(eid)
            pl_rm_mbs[#pl_rm_mbs+1] = world:sub{"entity_remove", eid}
        end
    end

    for msg in pl_rm_mbs:each() do
        local eid = msg[2]
        for _, os_eid in world:each "omni" do
            if eid == world[os_eid].omni.light_eid then
                w:remove(os_eid)
                break
            end
        end
    end
end

local function update_camera_matrices(camera)
    camera.viewmat	= math3d.inverse(camera.srt)
    camera.worldmat	= camera.srt
    camera.projmat	= math3d.projmat(camera.frustum, INV_Z)
    camera.infprojmat.m  = math3d.projmat(camera.frustum, INV_Z, INF_F)
    camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)
end

function omni_shadow_sys:update_camera()
    for oe in w:select "omni:in camera_ref:in" do
        local leid = oe.omni.light_eid
        if world[leid] then
            local camera = icamera.find_camera(oe.camera_ref)
            update_camera_matrices(camera)
        else
            log.warn(("entity id:%d, is not exist, but omni shadow entity still here"):format(leid))
        end
    end
end
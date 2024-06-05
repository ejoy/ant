local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local defaultcomp= import_package "ant.general".default

local hwi       = import_package "ant.hwi"

local math3d    = require "math3d"

local irq       = ecs.require "ant.render|renderqueue"
local queuemgr  = ecs.require "ant.render|queue_mgr"
local icamera   = ecs.require "ant.camera|camera"
local imaterial = ecs.require "ant.render|material"
local ientity   = ecs.require "ant.entity|entity"

local second_camera_sys = ecs.system "second_view_camera_system"

local second_view_width = 384
local second_view_height = 216

local function calc_second_view_viewport(vr)
    return {
        x = vr.x + math.max(0, vr.w - second_view_width),
        y = vr.y + math.max(0, vr.h - second_view_height),
        w = second_view_width, h = second_view_height
    }
end

local DEFAULT_camera

function second_camera_sys:init()
    queuemgr.register_queue "second_view"
end

function second_camera_sys:init_world()
    local mq = w:first "main_queue render_target:in"
    local mqrt = mq.render_target
    local vr = calc_second_view_viewport(mqrt.view_rect)
    DEFAULT_camera = icamera.create{
        eyepos  = mc.ZERO_PT,
        viewdir = mc.ZAXIS,
        updir   = mc.YAXIS,
        frustum = defaultcomp.frustum(vr.w / vr.h),
    }
    world:create_entity{
        policy = {
            "ant.render|render_queue",
        },
        data = {
            camera_ref = DEFAULT_camera,
            render_target = {
                view_rect = vr,
                viewid = hwi.viewid_generate "second_view",
                view_mode = mqrt.view_mode,
                clear_state = mqrt.clear_state,
                fb_idx = mqrt.fb_idx,
            },
            queue_name = "second_view",
            submit_queue = true,
            second_view = true,
            visible = true,
        },
        tag = {
            "second_view"
        }
    }
end

local event_mq_vr = world:sub{"view_rect_changed", "main_queue"}

function second_camera_sys:data_changed()
    for msg in event_mq_vr:each() do
        local vr = msg[3]
        local sv_vr = calc_second_view_viewport(vr)
        irq.set_view_rect("second_view", sv_vr)
    end
end

function second_camera_sys:update_camera()
    local svq = w:first "second_view visible camera_ref:in"
    if not svq then
        return
    end
    local ce <close> = world:entity(svq.camera_ref, "camera_changed?in camera:in scene:in")
    if ce.camera_changed then
        local camera, scene = ce.camera, ce.scene

        local pos, dir = math3d.index(scene.worldmat, 4, 3)
        icamera.update_camera_matrices(camera, math3d.lookto(pos, dir, scene.updir), camera.frustum)
    end
end

function second_camera_sys:entity_remove()
    for e in w:select "REMOVED camera:in eid:in" do
        local sc = w:first("second_view camera_ref:in")
        if e.eid == sc.camera_ref then
            irq.set_camera_from_queuename("second_view", DEFAULT_camera)
        end
    end
end


local sc_frustum_sys = ecs.system "second_view_frustum_system"

local frustum_ib<const> = {
	-- front
	0, 1, 2, 3,
	0, 2, 1, 3,

	-- back
	4, 5, 6, 7,
	4, 6, 5, 7,

	-- left
	0, 4, 1, 5,
	-- right
	2, 6, 3, 7,
}

local function scale_frustum_points(frustum_points, len)
    local dirs = {}

    local points = {
        math3d.array_index(frustum_points, 1),
        math3d.array_index(frustum_points, 2),
        math3d.array_index(frustum_points, 3),
        math3d.array_index(frustum_points, 4),
    }

    for i=1, 4 do
        local p1 = math3d.array_index(frustum_points, i+4)
        dirs[#dirs+1] = math3d.normalize(p1, points[i])
    end

    return {
        points[1], points[2], points[3], points[4],

        math3d.muladd(dirs[1], len, points[1]),
        math3d.muladd(dirs[2], len, points[2]),
        math3d.muladd(dirs[3], len, points[3]),
        math3d.muladd(dirs[4], len, points[4]),
    }
end

local function create_frustum_entity(eid)
    local e <close> = world:entity(eid, "camera:in")
    local camera = e.camera

    local function add_v(p, vb)
		local x, y, z = math3d.index(p, 1, 2, 3)
        vb[#vb+1] = x
        vb[#vb+1] = y
        vb[#vb+1] = z
    end

    local vb = {}
    local frustum_points = scale_frustum_points(math3d.frustum_points(camera.projmat), 3)

	for i=1, 8 do
        add_v(frustum_points[i], vb)
	end

    local frustum_root = world:create_entity {
        policy = {
            "ant.scene|scene_object",
        },
        data = {
            scene = { parent = eid },
            second_view_frustum = true,
        },
        tag = {
            "second_view_frustum_root"
        }
    }

    local function onready(e)
        imaterial.set_property(e, "u_color", mc.YELLOW_HALF)
    end

    world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            on_ready = onready,
            mesh_result = ientity.create_mesh({"p3", vb}, frustum_ib),
            material = "/pkg/ant.resources/materials/line_color.material",
            render_layer = "translucent",
            scene = { parent = frustum_root },
            visible = true,
            second_view_frustum = true,
        },
        tag = {
            "second_view_frustum"
        }
    }

    local tri_bottomcenter = math3d.mul(0.5, math3d.add(frustum_points[6], frustum_points[8]))
    local l<const> = math3d.length(frustum_points[6], frustum_points[8]) * 0.25
    local hl<const> = l * 0.5
    local h<const> = l * 2 / 3.0

    world:create_entity {
        policy = {
            "ant.render|simplerender",
        },
        data = {
            mesh_result = ientity.create_mesh{
                "p3",{
                    -hl, 0.0, 0.0,
                    0.0, h,   0.0,
                     hl, 0.0, 0.0,
                }
            },
            material = "/pkg/ant.resources/materials/singlecolor.material",
            visible = true,
            scene = {
                t = tri_bottomcenter,
                parent = frustum_root
            },
            on_ready = onready,
            second_view_frustum = true,
        },
        tag = {
            "second_view_triangle"
        }
    }
end

local function remove_frustum_entity()
    for e in w:select "second_view_frustum" do
        w:remove(e)
    end
end

local need_create_frustum_entity

local function show_frustum(visible)
    if visible then
        for _ in w:select "second_view visible camera_ref:in" do
            remove_frustum_entity()
            need_create_frustum_entity = true
        end
    else
        remove_frustum_entity()
    end
end

local event_sc_visible = world:sub{"queue_visible_changed", "second_view"}
function sc_frustum_sys:camera_usage()
    for _, _, visible in event_sc_visible:unpack() do
        show_frustum(visible)
    end
end

function sc_frustum_sys:entity_remove()
    if need_create_frustum_entity then
        for sc_q in w:select "second_view visible camera_ref:in" do
            create_frustum_entity(sc_q.camera_ref)
        end
        need_create_frustum_entity = nil
    end
end
local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local defaultcomp= import_package "ant.general".default

local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr

local math3d    = require "math3d"

local irq       = ecs.import.interface "ant.render|irenderqueue"
local ilight    = ecs.import.interface "ant.render|ilight"
local icamera   = ecs.import.interface "ant.camera|icamera"
local imesh     = ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"

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

function second_camera_sys:init_world()
    local mq = w:singleton("main_queue", "render_target:in")
    local mqrt = mq.render_target
    local vr = calc_second_view_viewport(mqrt.view_rect)
    DEFAULT_camera = icamera.create{
        eyepos  = mc.ZERO_PT,
        viewdir = mc.ZAXIS,
        updir   = mc.YAXIS,
        frustum = defaultcomp.frustum(vr.w / vr.h),
        name    = "second_view_camera",
    }
    ecs.create_entity{
        policy = {
            "ant.render|render_queue",
            "ant.general|name",
        },
        data = {
            camera_ref = DEFAULT_camera,
            render_target = {
                view_rect = vr,
                viewid = viewidmgr.generate "second_view",
                view_mode = mqrt.view_mode,
                clear_state = mqrt.clear_state,
                fb_idx = mqrt.fb_idx,
            },
            primitive_filter = {
                filter_type = "main_view",
                exclude_type = "auxgeom",
                "foreground", "opacity", "background", "translucent",
            },
            queue_name = "second_view",
            second_view = true,
            name = "second_view",
            visible = true,
        }
    }
end

local cc_mb

function second_camera_sys:entity_init()
    for q in w:select "INIT second_view camera_ref:in" do
        local cref = q.camera_ref
        cc_mb = world:sub{"camera_changed", cref}
    end
end

local mq_vr_mb = world:sub{"view_rect_changed", "main_queue"}
local sc_cc_mb = world:sub{"second_view", "camera_changed"}

function second_camera_sys:data_changed()
    for msg in mq_vr_mb:each() do
        local vr = msg[3]
        local sv_vr = calc_second_view_viewport(vr)
        irq.set_view_rect("second_view", sv_vr)
    end

    for _, _, cref in sc_cc_mb:unpack() do
        cc_mb = world:sub{"camera_changed", cref}
    end
end

function second_camera_sys:update_camera()
    for svq in w:select "second_view visible camera_ref:in" do
        local mc = world:entity(svq.camera_ref)
		local camera, scene = mc.camera, mc.scene

		local worldmat = scene._worldmat
		local pos, dir = math3d.index(worldmat, 4, 3)
		camera.viewmat = math3d.lookto(pos, dir, scene.updir)
		camera.projmat = math3d.projmat(camera.frustum)
		camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)
    end
end

function second_camera_sys:entity_remove()
    for e in w:select "REMOVED camera:in id:in" do
        local sc = w:singleton("second_view", "camera_ref:in")
        if e.id == sc.camera_ref then
            irq.set_camera("second_view", DEFAULT_camera)
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

    for i=1, 4 do
        dirs[#dirs+1] = math3d.normalize(math3d.sub(frustum_points[i+4], frustum_points[i]))
    end

    return {
        frustum_points[1],
        frustum_points[2],
        frustum_points[3],
        frustum_points[4],

        math3d.muladd(dirs[1], len, frustum_points[1]),
        math3d.muladd(dirs[2], len, frustum_points[2]),
        math3d.muladd(dirs[3], len, frustum_points[3]),
        math3d.muladd(dirs[4], len, frustum_points[4]),
    }
end

local function create_frustum_entity(eid)
    local e = world:entity(eid)
    local camera = e.camera

    local function add_v(p, vb)
		local x, y, z = math3d.index(p, 1, 2, 3)
        vb[#vb+1] = x
        vb[#vb+1] = y
        vb[#vb+1] = z
    end

    local vb = {}
    local frustum_points = scale_frustum_points(math3d.frustum_points(camera.projmat), 3)

	for i=1, #frustum_points do
        add_v(frustum_points[i], vb)
	end

    local frustum_root = ecs.create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.general|name"
        },
        data = {
            scene = {srt={}},
            name = "second_view_frustum_root",
            second_view_frustum = true,
            on_ready = function (e)
                w:sync("id:in", e)
                ecs.method.set_parent(e.id, eid)
            end,
        }
    }

    local color = mc.COLOR(mc.YELLOW_HALF, ilight.default_intensity "point")
    local function onready(e)
        w:sync("id:in", e)
        ecs.method.set_parent(e.id, frustum_root)
        imaterial.set_property(e, "u_color", color)
    end

    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            on_ready = onready,
            simplemesh = imesh.init_mesh{
                vb = {
                    start = 0,
                    num = 8,
                    {
                        declname = "p3",
                        memory = {"fff", vb},
                    },
                },
                ib = {
                    start = 0,
                    num = #frustum_ib,
                    memory = {"w", frustum_ib},
                }
            },
            owned_mesh_buffer = true,
            material = "/pkg/ant.resources/materials/line_color.material",
            scene = {srt={}},
            filter_state = "main_view|auxgeom",
            name = "second_view_frustum",
            second_view_frustum = true,
        }
    }

    local tri_bottomcenter = math3d.mul(0.5, math3d.add(frustum_points[6], frustum_points[8]))
    local tri_edge_len<const> = math3d.length(frustum_points[6], frustum_points[8]) * 0.25
    local tri_edge_len_half<const> = tri_edge_len * 0.5
    local tri_edge_height<const> = tri_edge_len * 2 / 3.0

    ecs.create_entity {
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = imesh.init_mesh{
                vb = {
                    start = 0,
                    num = 3,
                    {
                        declname = "p3",
                        memory = {"fff", {
                            -tri_edge_len_half, 0.0, 0.0,
                            0.0, tri_edge_height, 0.0,
                            tri_edge_len_half, 0.0, 0.0,
                        }}
                    }
                }
            },
            owned_mesh_buffer = true,
            material = "/pkg/ant.resources/materials/singlecolor.material",
            filter_state = "main_view|auxgeom",
            scene = {srt={
                t = tri_bottomcenter,
            }},
            name = "second_view_triangle",
            on_ready = onready,
            second_view_frustum = true,
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

local sc_visible_mb = world:sub{"queue_visible_changed", "second_view"}
function sc_frustum_sys:camera_usage()
    for _, _, visible in sc_visible_mb:unpack() do
        show_frustum(visible)
    end

    for _ in cc_mb:each() do
        show_frustum(true)
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
local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local ientity = world:interface "ant.render|entity"
local ies = world:interface "ant.scene|ientity_state"
local init_loader_sys = ecs.system 'init_loader_system'
local imaterial = world:interface "ant.asset|imaterial"
local mc = import_package"ant.math".constant
local geo = import_package "ant.geometry".geometry

local function create_plane_test()
    local planes = {
        {
            srt = {s ={50, 1, 50}},
            color = {0.8, 0.8, 0.8, 1},
            material = "/pkg/ant.resources/materials/mesh_shadow.material",
        },
    }

    for _, p in ipairs(planes) do
        local eid = ientity.create_plane_entity(
            p.srt,
            p.material,
            "test shadow plane",
            {
                ["ant.collision|collider_policy"] = {
                    collider = {
                        box = {{
                            origin = { 0, 0, 0, 1 },
                            size = {50, 0.001, 50},
                        }}
                    },
                },
                ["ant.render|debug_mesh_bounding"] = {
                    debug_mesh_bounding = true,
                }
            })
        imaterial.set_property(eid, "u_basecolor_factor", p.color)
    end
end

local icamera = world:interface "ant.camera|camera"
local iom = world:interface "ant.objcontroller|obj_motion"

local function target_lock_test()
    local eid = world:create_entity{
        policy = {
            "ant.general|name",
            "ant.render|render",
        },
        data = {
            name = "lock_target",
            state = ies.create_state "visible",
            transform =  {
                s = {2, 1, 2, 0},
                t = {16, 1, 6},
            },
            mesh = "/pkg/ant.resources/meshes/sphere.mesh",
            material = "/pkg/ant.resources/materials/bunny.material",
            scene_entity = true,
        }
    }

    local lock_eid = world:create_entity {
        policy = {
            "ant.general|name",
            "ant.render|render",
            "ant.scene|hierarchy_policy",
            "ant.scene|lock_target_policy",
        },
        data = {
            name = "lock_obj",
            state = ies.create_state "visible",
            transform =  {t={0, 0, -6}},
            lock_target = {
                type = "ignore_scale",
                offset = {0, 0, 3},
            },
            mesh = "/pkg/ant.resources/meshes/cube.mesh",
            material = "/pkg/ant.resources/materials/singlecolor.material",
            scene_entity = true,
        },
        action = {
            mount = eid,
        }
    }
end

local function find_entity(name, whichtype)
    for _, eid in world:each(whichtype) do
        if world[eid].name:match(name) then
            return eid
        end
    end
end

local function point_light_test()
    local pl_pos = {
        {  1, 0, 1},
        { -1, 0, 1},
        { -1, 0,-1},
        {  1, 0,-1},
        {  1, 2, 1},
        { -1, 2, 1},
        { -1, 2,-1},
        {  1, 2,-1},

        {  3, 0, 3},
        { -3, 0, 3},
        { -3, 0,-3},
        {  3, 0,-3},
        {  3, 2, 3},
        { -3, 2, 3},
        { -3, 2,-3},
        {  3, 2,-3},
    }

    -- for _, p in ipairs(pl_pos) do
    --     local  lighteid = world:instance "/pkg/ant.test.features/assets/entities/light_point.prefab"[1]
    --     iom.set_position(lighteid, p)
    -- end

    -- local cubeeid = world:instance "/pkg/ant.test.features/assets/entities/pbr_cube.prefab"[1]
    -- iom.set_position(cubeeid, {0, 0, 0, 1})

    for _, r in ipairs{
        math3d.quaternion{2.4, 0, 0},
        math3d.quaternion{-2.4, 0, 0},
        math3d.quaternion{0, 1, 0},
    } do
        local eid = world:instance "/pkg/ant.test.features/assets/entities/light_directional.prefab"[1]
        iom.set_rotation(eid, r)
    end
end

local icc = world:interface "ant.test.features|icamera_controller"
local iccqs = world:interface "ant.quad_sphere|icamera_controller"

function init_loader_sys:init()
    point_light_test()
    ientity.create_grid_entity("polyline_grid", 64, 64, 1, 5)

    --world:instance "/pkg/ant.test.features/assets/entities/font_tt.prefab"
    --world:instance "/pkg/ant.resources.binary/meshes/female/female.glb|mesh.prefab"

    ientity.create_procedural_sky()
    --target_lock_test()

    world:instance "/pkg/ant.resources.binary/meshes/testBDcloud.glb|mesh.prefab"

    icc.create()
    iccqs.create()
end

local camera_cache = {
    icc = {
        pos = math3d.ref(math3d.vector()),
        dir = math3d.ref(math3d.vector()),
        updir = math3d.ref(math3d.vector()),
    },
    iccqs = {
        pos = math3d.ref(math3d.vector()),
        dir = math3d.ref(math3d.vector()),
        updir = math3d.ref(math3d.vector()),
    }
}

function init_loader_sys:post_init()
    local mq = world:singleton_entity "main_queue"

    local eid = world:instance "/pkg/ant.test.features/assets/entities/cube.prefab"[1]
    iom.set_scale(eid, 0.1)

    icc.attach(mq.camera_eid)
    iccqs.attach(mq.camera_eid)
    icamera.controller(mq.camera_eid, iccqs.get())

    camera_cache.icc.pos.v = {-10.5, 10, -5.5, 1}
    camera_cache.icc.dir.v = math3d.sub(mc.ZERO_PT, camera_cache.icc.pos)
    camera_cache.icc.updir.v = mc.YAXIS
    icamera.lookto(mq.camera_eid, camera_cache.icc.pos, camera_cache.icc.dir)
    -- icamera.set_dof(mq.camera_eid, {
    --     -- aperture_fstop      = 2.8,
    --     -- aperture_blades     = 0,
    --     -- aperture_rotation   = 0,
    --     -- aperture_ratio      = 1,
    --     -- sensor_size         = 100,
    --     -- focus_distance      = 5,
    --     -- focal_len           = 84,
    --     focuseid            = world:create_entity {
    --         policy = {
    --             "ant.render|simplerender"
    --         },
    --         data = {
    --             transform = {},
    --             simplemesh = {},
    --             state = "",
    --         }
    --     },
    --     enable              = true,
    -- })
    -- local dir = {0, 0, 1, 0}
    -- icamera.lookto(mq.camera_eid, {0, 0, -8, 1}, dir)
    local f = icamera.get_frustum(mq.camera_eid)
    f.n, f.f = 0.25, 250
    icamera.set_frustum(mq.camera_eid, f)

    -- local ipl = world:interface "ant.render|ipolyline"
    -- ipl.add_strip_lines({
    --     {0, 0, 0}, {0.5, 0, 1}, {1, 0, 0},
    -- }, 15, {1.0, 1.0, 0.0, 1.0})
end

local kb_mb = world:sub{"keyboard"}
function init_loader_sys:data_changed()
    for _, key, press, status in kb_mb:unpack() do
        if key == "X" and press == 0 then
            local mq = world:singleton_entity "main_queue"

            local isicc = icc.get() == icamera.controller(mq.camera_eid)
            local c = isicc and camera_cache.icc or camera_cache.iccqs
            c.pos.v = iom.get_position(mq.camera_eid)
            c.dir.v = iom.get_direction(mq.camera_eid)
            c.updir.v = iom.get_updir(mq.camera_eid)

            local uc = isicc and camera_cache.iccqs or camera_cache.icc

            iom.lookto(mq.camera_eid, uc.pos, uc.dir, uc.updir)
            icamera.controller(mq.camera_eid, isicc and iccqs.get() or icc.get())
        end
    end
end

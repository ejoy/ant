local ecs = ...
local world = ecs.world

local fs = require 'filesystem'

local serialize = import_package 'ant.serialize'

local math3d = require "math3d"

local skypkg = import_package 'ant.sky'
local skyutil = skypkg.util

local renderpkg = import_package 'ant.render'
local computil  = renderpkg.components

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local init_loader = ecs.system 'init_loader'

init_loader.require_system "ant.imguibase|imgui_system"
init_loader.require_system "ant.sky|procedural_sky_system"
init_loader.require_system "ant.test.features|scenespace_test"
init_loader.require_system "ant.test.features|character_ik_test"
init_loader.require_system "ant.test.features|terrain_test"
init_loader.require_system "ant.test.features|pbr_test"
init_loader.require_system "ant.test.features|animation_test"
init_loader.require_system 'ant.test.features|camera_controller'
init_loader.require_system "ant.render|physic_bounding"
init_loader.require_system "ant.render|render_mesh_bounding"

init_loader.require_interface "ant.render|camera"
init_loader.require_interface "ant.objcontroller|camera_motion"
init_loader.require_interface "ant.objcontroller|obj_motion"
init_loader.require_interface "ant.render|iwidget_drawer"
init_loader.require_interface "ant.render|light"

init_loader.require_policy "ant.objcontroller|obj_lock"
init_loader.require_policy "ant.objcontroller|camera_lock"

local function create_plane_test()
    local planes = {
        {
            transform = {srt={s={50, 1, 50}}},
            color = {0.8, 0.8, 0.8, 1},
            material = fs.path "/pkg/ant.resources/depiction/materials/test/mesh_shadow.material",
        },
    }

    for _, p in ipairs(planes) do
        computil.create_plane_entity(world,
            p.transform,
            p.material,
            p.color,
            "test shadow plane",
            {
                ["ant.collision|collider"] = {
                    collider = {
                        box = {
                            {
                                origin = {0, 0, 0, 1},
                                size = {50, 0.001, 50},
                            }
                        }
                    },
                },
                ["ant.render|debug_mesh_bounding"] = {
                    debug_mesh_bounding = true,
                }
            })
    end
end

local icamera = world:interface "ant.render|camera"
local icm = world:interface "ant.objcontroller|camera_motion"
local iom = world:interface "ant.objcontroller|obj_motion"

local ilight = world:interface "ant.render|light"

local function target_lock_test()
    local eid = world:create_entity{
        policy = {
            "ant.render|name",
            "ant.render|render",
            "ant.render|mesh",
            "ant.serialize|serialize"
        },
        data = {
            name = "lock_target",
            can_render = true,
            transform = {srt = {
                s = {2, 1, 2, 0},
                t = {16, 1, 6}},
            },
            rendermesh = {},
            mesh = "/pkg/ant.resources/depiction/meshes/sphere.mesh",
            material = "/pkg/ant.resources/depiction/materials/bunny.material",
            serialize = serialize.create(),
        }
    }

    local lock_eid = world:create_entity {
        policy = {
            "ant.render|name",
            "ant.render|render",
            "ant.render|mesh",
            "ant.objcontroller|obj_lock",
            "ant.serialize|serialize"
        },
        data = {
            name = "lock_obj",
            can_render = true,
            transform = {srt={t={0, 0, -6}}},
            rendermesh = {},
            mesh = "/pkg/ant.resources/depiction/meshes/cube.mesh",
            material = "/pkg/ant.resources/depiction/materials/singlecolor.material",
                --properties = {
                --    uniforms = {
                --        u_color = {type="v4", name="vv", value={1, 0, 0, 1}}
                --    }
                --}
            serialize = serialize.create(),
            lock_target = {
                type = "ignore_scale",
                target = world[eid].serialize,
                offset = {0, 0, 3},
            },
        },
    }
end

local function find_entity(name, whichtype)
    for _, eid in world:each(whichtype) do
        if world[eid].name:match(name) then
            return eid
        end
    end
end

function init_loader:init()
    do
        local dlightdir = math3d.totable(
            math3d.normalize(math3d.inverse(math3d.todirection(
                math3d.quaternion(mu.to_radian{60, 50, 0, 0}))
        )))
        ilight.create_directional_light_entity("direction light", 
		{1,1,1,1}, 2, dlightdir)
        ilight.create_ambient_light_entity('ambient_light', 'gradient', {1, 1, 1, 1})
    end

    skyutil.create_procedural_sky(world)
    target_lock_test()
end

local function create_camera()
    local rotation = math3d.quaternion{math.rad(30), math.rad(150), 0}
    local id = icamera.create {
        eyepos  = {-4.5, 2, -1.5, 1},
        viewdir = math3d.totable(math3d.todirection(rotation)),
        name = "features_camera",
        lock_target = {
            type = "rotate",
            target = "",
        }
    }
    icamera.bind(id, "main_queue")
    return id
end

function init_loader:post_init()
    create_camera()
end

local imgui      = require "imgui"
local wndflags = imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }

function init_loader:ui_update()
    local mq = world:singleton_entity "main_queue"
    local cameraeid = mq.camera_eid

    local widget = imgui.widget
    imgui.windows.Begin("Test", wndflags)
    if widget.Button "rotate_camera" then
        icm.rotate(cameraeid, {math.rad(10), 0, 0})
    end

    if widget.Button "move_camera" then
        icm.move(cameraeid, {1, 0, 0})
    end

    if widget.Button "camera_lock_target_for_move" then
        local foundeid = find_entity("lock_target", "can_render")
        if foundeid then
            icm.target(cameraeid, "move", foundeid, {0, 1, 0})
        else
            print "not found animation_sample"
        end
        
    end

    if widget.Button "camera_lock_target_for_rotate" then
        local foundeid = find_entity("lock_target", "can_render")
        if foundeid then
            icm.target(cameraeid, "rotate", foundeid)
        else
            print "not found gltf entity"
        end
    end

    if widget.Button "move_target" then
        local foundeid = find_entity("lock_target", "can_render")
        if foundeid then
            iom.move(foundeid, {0, 0, 1})
        end
    end

    if widget.Button "rotate_target" then
        local foundeid = find_entity("lock_target", "can_render")
        if foundeid then
            iom.rotate(foundeid, math.rad(3), 0)
        end
    end

    imgui.windows.End()
end
local ecs = ...
local world = ecs.world

local fs = require 'filesystem'

local math3d = require "math3d"

local skypkg = import_package 'ant.sky'
local skyutil = skypkg.util

local renderpkg = import_package 'ant.render'
local computil  = renderpkg.components

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local init_loader_sys = ecs.system 'init_loader_system'

local function create_plane_test()
    local planes = {
        {
            transform = {srt={s ={50, 1, 50}}},
            color = {0.8, 0.8, 0.8, 1},
            material = "/pkg/ant.resources/materials/test/mesh_shadow.material",
        },
    }

    for _, p in ipairs(planes) do
        computil.create_plane_entity(world,
            p.transform,
            p.material,
            p.color,
            "test shadow plane",
            {
                ["ant.collision|collider_policy"] = {
                    collider = world.component:collider{
                        box = {
                            world.component:box_shape{
                                origin = math3d.ref(math3d.vector(0, 0, 0, 1)),
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
            "ant.general|name",
            "ant.render|render",
            "ant.render|mesh",
        },
        data = {
            name = "lock_target",
            can_render = true,
            transform = world.component:transform {srt = world.component:srt {
                s = world.component:vector {2, 1, 2, 0},
                t = world.component:vector {16, 1, 6}},
            },
            mesh = world.component:resource "/pkg/ant.resources/meshes/sphere.mesh",
            material = world.component:resource "/pkg/ant.resources/materials/bunny.material",
            scene_entity = true,
        }
    }

    local lock_eid = world:create_entity {
        policy = {
            "ant.general|name",
            "ant.render|render",
            "ant.render|mesh",
            "ant.scene|hierarchy_policy",
        },
        data = {
            name = "lock_obj",
            can_render = true,
            parent = eid,
            transform = world.component:transform {
                srt= world.component:srt {t= world.component:vector {0, 0, -6}},
                lock_target = {
                    type = "ignore_scale",
                    offset = {0, 0, 3},
                },
            },
            mesh = world.component:resource "/pkg/ant.resources/meshes/cube.mesh",
            material = world.component:resource "/pkg/ant.resources/materials/singlecolor.material",
            scene_entity = true,
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

function init_loader_sys:init()
    do
        local rotator = math3d.quaternion{math.rad(60), 0, 0}
        local dlightdir = math3d.tovalue(
            math3d.normalize(
                math3d.inverse(math3d.todirection(rotator))
        ))
        ilight.create_directional_light_entity("direction light", 
		{1,1,1,1}, 2, dlightdir, {0, 3, 0, 1})
        ilight.create_ambient_light_entity('ambient_light', 'gradient', {1, 1, 1, 1})
    end

    computil.create_procedural_sky(world)
    target_lock_test()
end

local function create_camera()
    local dir = math3d.todirection(math3d.quaternion{math.rad(30), math.rad(150), 0})
    local mq = world:singleton_entity "main_queue"
    local camera_eid = mq.camera_eid

    icm.set_direction(camera_eid, dir)
    icm.set_position(camera_eid, {-4.5, 2, -1.5, 1})
end

function init_loader_sys:post_init()
    create_camera()
end

local seri = import_package "ant.serialize"

local kb_mb = world:sub {"keyboard"}
function init_loader_sys:data_changed()
    for _, key, press, what in kb_mb:unpack() do
        if key == "SPACE" then
            for _, eid in world:each "can_render" do
                local r = seri.entity(world, eid)
                print(r)
            end
        end
    end
end

local imgui      = require "imgui"
local wndflags = imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }

function init_loader_sys:ui_update()
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
            icm.set_lock_target(cameraeid, {type = "move", offset = {0, 1, 0}})
        else
            print "not found animation_sample"
        end
        
    end

    if widget.Button "camera_lock_target_for_rotate" then
        local foundeid = find_entity("lock_target", "can_render")
        if foundeid then
            icm.set_lock_target(cameraeid, {type="rotate"})
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
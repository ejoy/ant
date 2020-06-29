local ecs = ...
local world = ecs.world

local fs = require 'filesystem'

local math3d = require "math3d"

local computil = world:interface "ant.render|entity"

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local init_loader_sys = ecs.system 'init_loader_system'
local imaterial = world:interface "ant.asset|imaterial"

local function create_plane_test()
    local planes = {
        {
            srt = {s ={50, 1, 50}},
            color = {0.8, 0.8, 0.8, 1},
            material = "/pkg/ant.resources/materials/mesh_shadow.material",
        },
    }

    for _, p in ipairs(planes) do
        local eid = computil.create_plane_entity(
            p.srt,
            p.material,
            "test shadow plane",
            {
                ["ant.collision|collider_policy"] = {
                    collider = world.component "collider" {
                        box = {
                            world.component "box_shape" {
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
        imaterial.set_property(eid, "u_basecolor_factor", p.color)
    end
end

local icamera = world:interface "ant.camera|camera"
local iom = world:interface "ant.objcontroller|obj_motion"

local ilight = world:interface "ant.render|light"

local function target_lock_test()
    local eid = world:create_entity{
        policy = {
            "ant.general|name",
            "ant.render|render",
        },
        data = {
            name = "lock_target",
            can_render = true,
            transform =  {
                s = world.component "vector" {2, 1, 2, 0},
                t = world.component "vector" {16, 1, 6},
            },
            mesh = world.component "resource" "/pkg/ant.resources/meshes/sphere.mesh",
            material = world.component "resource" "/pkg/ant.resources/materials/bunny.material",
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
            can_render = true,
            parent = eid,
            transform =  {t={0, 0, -6}},
            lock_target = {
                type = "ignore_scale",
                offset = {0, 0, 3},
            },
            mesh = world.component "resource" "/pkg/ant.resources/meshes/cube.mesh",
            material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material",
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
        world:instance("/pkg/ant.test.features/assets/entities/light_directional.prefab", {})
        ilight.create_ambient_light_entity('ambient_light', 'gradient', {1, 1, 1, 1})
    end

    computil.create_grid_entity()

    computil.create_procedural_sky()
    --target_lock_test()
end

function init_loader_sys:post_init()
    local mq = world:singleton_entity "main_queue"
    local dir = math3d.todirection(math3d.quaternion{math.rad(30), math.rad(150), 0})
    icamera.lookto(mq.camera_eid, {-4.5, 2, -1.5, 1}, dir)
    --local dir = {0, 0, -1, 0}
    --icamera.lookto(mq.camera_eid, {0, 0, 0, 1}, dir)
end

local imgui      = require "imgui"
local wndflags = imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }

function init_loader_sys:ui_update()
    local mq = world:singleton_entity "main_queue"
    local cameraeid = mq.camera_eid

    local widget = imgui.widget
    imgui.windows.Begin("Test", wndflags)
    if widget.Button "rotate_camera" then
        iom.rotate(cameraeid, 1, 0)
    end

    if widget.Button "move_camera" then
        iom.move(cameraeid, {1, 0, 0})
    end

    if widget.Button "camera_lock_target_for_move" then
        local foundeid = find_entity("lock_target", "can_render")
        if foundeid then
            iom.set_lock_target(cameraeid, {type = "move", offset = {0, 1, 0}})
        else
            print "not found animation_sample"
        end
        
    end

    if widget.Button "camera_lock_target_for_rotate" then
        local foundeid = find_entity("lock_target", "can_render")
        if foundeid then
            iom.set_lock_target(cameraeid, {type="rotate"})
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
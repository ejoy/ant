-- local ecs = ...
local world = ecs.world

assert(false, "not world for new math3d")

local math3d    = require "math3d"

local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera

local camera_controller_system = ecs.system "editor_camera_controller"
camera_controller_system.require_interface "ant.camera_controller|camera_motion"
local icm = world:interface "ant.camera_controller|camera_motion"

ecs.tag "test_remove_com"

-- ecs.component "camera_control"
--     .scale "boolean"
--     .move "boolean"

local leftmouse_mb = world:sub {"mouse", "LEFT"}
local rightmouse_mb = world:sub {"mouse", "RIGHT"}
local mousewheel_mb = world:sub {"mouse_wheel", }

local move_speed = 0.1
local wheel_speed = 1
local last_x, last_y

local target = math3d.ref(math3d.vector())

local function delta_move(x, y)
    return (x - last_x) * move_speed, (y - last_y) * move_speed
end

function camera_controller_system:update()
    for _,_, _, x, y in leftmouse_mb:unpack() do
        local mq = world:single_entity "main_queue"
        local cameraeid = mq.camera_eid
        local camera = world[cameraeid].camera

        local dx, dy = delta_move(x, y)

        local distance = math3d.length(math3d.sub(target, camera.eyepos))
        icm.rotate_round_point(cameraeid, target, distance, dy, dx)
    end

    for _, _, _, x, y in rightmouse_mb:unpack() do
        local mq = world:single_entity "main_queue"
        local cameraeid = mq.camera_eid
        local camera = world[cameraeid].camera

        local dx, dy = delta_move(x, y)
        local offset = math3d.sub(target, camera.eyepos)
        icm.move_along(cameraeid, {-dx, dy})
        target.v = math3d.add(camera.eyepos, offset)
    end

    for _, x, y, delta in mousewheel_mb:unpack() do
        local mq = world:single_entity "main_queue"
        local cameraeid = mq.camera_eid
        local camera = world[cameraeid].camera

        icm.move_along_axis(cameraeid, camera.viewdir, delta)
    end
end

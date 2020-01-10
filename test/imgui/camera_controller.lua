local ecs = ...
local world = ecs.world

local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local ms        = mathpkg.stack
local point2d   = mathpkg.point2d

local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera

local camera_controller_system = ecs.system "editor_camera_controller"

ecs.tag "test_remove_com"

-- ecs.component "camera_control"
--     .scale "boolean"
--     .move "boolean"

local function camera_move(forward_axis, position, dx, dy, dz)
    --ms(position, rotation, "b", position, "S", {dx}, "*+S", {dy}, "*+S", {dz}, "*+=") 
    local right_axis, up_axis = ms:base_axes(forward_axis)
    ms(position, 
        position, 
            right_axis, {dx}, "*+", 
            up_axis, {dy}, "*+", 
            forward_axis, {dz}, "*+=")
end

local leftmouse_mb = world:sub {"mouse", "LEFT"}
local rightmouse_mb = world:sub {"mouse", "RIGHT"}
local mousewheel_mb = world:sub {"mouse_wheel", }

local move_speed = 1
local wheel_speed = 1
local last_xy

local target = math3d.ref "vector" {0, 0, 0, 1}

function camera_controller_system:update()
    for _,_, _, x, y in leftmouse_mb:unpack() do
        local camera = camerautil.main_queue_camera(world)
        local xy = point2d(x, y)

        local speed = move_speed * 0.1
        local delta = (xy - last_xy) * speed
        local distance = math.sqrt(ms(target, camera.eyepos, "-1.T")[1])
        camera_move(camera.viewdir, camera.eyepos, -delta.x, delta.y, 0)
        ms(camera.viewdir, target, camera.eyepos, "-n=")
        ms(camera.eyepos, target, {-distance}, camera.viewdir, "*+=")
    end

    for _, _, _, x, y in rightmouse_mb:unpack() do
        local camera = camerautil.main_queue_camera(world)
        local xy = point2d(x, y)

        local speed = move_speed * 0.1
        local delta = (xy - last_xy) * speed
        camera_move(camera.viewdir, target, -delta.x, delta.y, 0)
        camera_move(camera.viewdir, camera.eyepos, -delta.x, delta.y, 0)
    end

    for _, x, y, delta in mousewheel_mb:unpack() do
        local camera = camerautil.main_queue_camera(world)
        camera_move(camera.viewdir, camera.eyepos, 0, 0, delta * wheel_speed)
    end
end

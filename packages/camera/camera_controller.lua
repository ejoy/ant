local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"

local iom = ecs.import.interface "ant.objcontroller|iobj_motion"

local cc_sys = ecs.system "default_camera_controller"

local kb_mb = world:sub {"keyboard"}
local evMouseMove = world:sub {"mouse", "LEFT"}


local viewat<const> = math3d.ref(math3d.vector(0, 0, 0))

local mouse_lastx, mouse_lasty
local toforward
function cc_sys:data_changed()
    for msg in kb_mb:each() do
        local key, press, status = msg[2], msg[3], msg[4]
        if press == 1 then
            if key == "W" then
                toforward = 0.1
            elseif key == "S" then
                toforward = -0.1
            end
        else
            toforward = nil
        end
    end

    local newx, newy
    for _, _, state, x, y in evMouseMove:unpack() do
        if state == "DOWN" then
            newx, newy = x, y
            mouse_lastx, mouse_lasty = x, y
        elseif state == "MOVE" then
            newx, newy = x, y
        elseif state == "UP" then
        end
    end

    if toforward then
        local mq = w:singleton("main_queue", "camera_ref:in")
        iom.move_forward(mq.camera_ref, toforward)
    end

    if newx and newy then
        local mq = w:singleton("main_queue", "camera_ref:in render_target:in")
        local rect = mq.render_target.view_rect
        local dx = (newx - mouse_lastx) / rect.w * 10
        local dy = (newy - mouse_lasty) / rect.h * 10
        mouse_lastx, mouse_lasty = newx, newy
        iom.rotate_around_point2(mq.camera_ref, viewat, dy, dx)
    end
end
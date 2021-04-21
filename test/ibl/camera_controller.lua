local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local iom = world:interface "ant.objcontroller|obj_motion"

local cc_sys = ecs.system "camera_controller"

local kb_mb = world:sub {"keyboard"}
local mouse_mb = world:sub {"mouse"}


local viewat<const> = math3d.ref(math3d.vector(0, 0, 0))

function cc_sys:post_init()
    local mq = world:singleton_entity "main_queue"
    local cameraeid = mq.camera_eid
    local eyepos = math3d.vector(0, 0, -10)
    iom.set_position(cameraeid, eyepos)
    local dir = math3d.normalize(math3d.sub(viewat, eyepos))
    iom.set_direction(cameraeid, dir)
end

local mouse_lastx, mouse_lasty
local toforward
function cc_sys:data_changed()
    for msg in kb_mb:each() do
        local key, press, status = msg[2], msg[3], msg[4]
        if press == 1 then
            if key == "W" then
                toforward = -0.01
            elseif key == "S" then
                toforward = 0.01
            end
        else
            toforward = nil
        end
    end

    local dx, dy
    for msg in mouse_mb:each() do
        local btn, state = msg[2], msg[3]
        local x, y = msg[4], msg[5]
        if btn == "LEFT" and state == "MOVE" then
            dx, dy = (x - mouse_lastx) * 0.01, (y - mouse_lasty) * 0.01
        end

        mouse_lastx, mouse_lasty = x, y
    end

    if toforward then
        local mq = world:singleton_entity "main_queue"
        local cameraeid = mq.camera_eid
        iom.move_forward(cameraeid, toforward)
    end

    if dx or dy then
        local mq = world:singleton_entity "main_queue"

        local cameraeid = mq.camera_eid
        iom.rotate_forward_vector(cameraeid, dy, dx)
    end
end
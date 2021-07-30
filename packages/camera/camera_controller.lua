local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"

local iom = world:interface "ant.objcontroller|obj_motion"

local cc_sys = ecs.system "default_camera_controller"

local kb_mb = world:sub {"keyboard"}
local mouse_mb = world:sub {"mouse"}


local viewat<const> = math3d.ref(math3d.vector(0, 0, 0))

function cc_sys:post_init()
    
end

local mouse_lastx, mouse_lasty
local toforward
function cc_sys:data_changed()
    for v in w:select "INIT main_queue camera_eid:in" do
        local eyepos = math3d.vector(0, 0, -10)
        local ceid = v.camera_eid
        iom.set_position(ceid, eyepos)
        local dir = math3d.normalize(math3d.sub(viewat, eyepos))
        iom.set_direction(ceid, dir)
    end

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
        iom.rotate_around_point2(cameraeid, viewat, dy, dx)
    end
end
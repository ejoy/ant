local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"

local iom = ecs.import.interface "ant.objcontroller|iobj_motion"

local cc_sys = ecs.system "default_camera_controller"

local kb_mb             = world:sub {"keyboard"}
local mouse_mb          = world:sub {"mouse"}
local mouse_wheel_mb    = world:sub {"mouse_wheel"}

local viewat = math3d.ref(math3d.vector(0, 0, 0))

local viewat_change_mb = world:sub{"camera_controller", "viewat"}
local move_speed_change_mb = world:sub{"camera_controller", "move_speed"}
local inc_move_speed_mb = world:sub{"camera_controller", "inc_move_speed"}
local dec_move_speed_mb = world:sub{"camera_controller", "dec_move_speed"}
local move_speed_delta_change_mb = world:sub{"camera_controller", "move_speed_delta"}

local mouse_lastx, mouse_lasty
local move_x, move_y, move_z
local mouse_btn
local mouse_state
local move_speed_delta = 0.01
local move_speed = 0.1

local function check_update_control()
    for _, _, pt in viewat_change_mb:unpack() do
        viewat = pt
    end

    for _, _, s in move_speed_change_mb:unpack() do
        move_speed = s
    end

    for _ in inc_move_speed_mb:each() do
        move_speed = move_speed + move_speed_delta
    end

    for _ in dec_move_speed_mb:each() do
        move_speed = move_speed + move_speed_delta
    end

    for _, _, d in move_speed_delta_change_mb:unpack() do
        move_speed_delta = move_speed_delta + d
    end

end

local function dxdy(x, y, rect)
    local dx = (x - mouse_lastx) / rect.w * 10
    local dy = (y - mouse_lasty) / rect.h * 10
    return dx, dy
end

function cc_sys:data_changed()
    check_update_control()

    for _, delta in mouse_wheel_mb:unpack() do
        local mq = w:singleton("main_queue", "camera_ref:in")
        local d = delta > 0 and move_speed or -move_speed
        iom.move_forward(mq.camera_ref, d)
    end

    for _, key, press, status in kb_mb:unpack() do
        if mouse_btn == "RIGHT" then
            local pressed = press == 1 or press == 2
            if key == "A" then
                move_x = pressed and -move_speed or nil
            elseif key == "D" then
                move_x = pressed and  move_speed or nil
            elseif key == "Q" then
                move_y = pressed and -move_speed or nil
            elseif key == "E" then
                move_y = pressed and  move_speed or nil
            elseif key == "S" then
                move_z = pressed and -move_speed or nil
            elseif key == "W" then
                move_z = pressed and  move_speed or nil
            end
        else
            if status.SHIFT then
                if press == 0 then
                    if key == "EQUALS" then --'+'
                        move_speed = move_speed + move_speed_delta
                    elseif key == "MINUS" then --'-'
                        move_speed = move_speed - move_speed_delta
                    end
                end
            end
        end
    end

    local newx, newy
    local motiontype
    for _, btn, state, x, y in mouse_mb:unpack() do
        mouse_state = state
        mouse_btn = btn
        if state == "DOWN" then
            newx, newy = x, y
            mouse_lastx, mouse_lasty = x, y
        elseif state == "MOVE" then
            newx, newy = x, y
        end

        if btn == "LEFT" then
            motiontype = "rotate_point"
        elseif btn == "RIGHT" then
            motiontype = "rotate_forwardaxis"
        elseif btn == "MIDDLE" then
            motiontype = "move_pan"
        end
    end

    if move_x then
        local mq = w:singleton("main_queue", "camera_ref:in")
        iom.move_right(mq.camera_ref, move_x)
    end

    if move_y then
        local mq = w:singleton("main_queue", "camera_ref:in")
        iom.move_up(mq.camera_ref, move_y)
    end

    if move_z then
        local mq = w:singleton("main_queue", "camera_ref:in")
        iom.move_forward(mq.camera_ref, move_z)
    end

    if newx and newy then
        if motiontype == "rotate_point" then
            local mq = w:singleton("main_queue", "camera_ref:in render_target:in")
            local dx, dy = dxdy(newx, newy, mq.render_target.view_rect)
            mouse_lastx, mouse_lasty = newx, newy
            iom.rotate_around_point2(mq.camera_ref, viewat, dy, dx)
        elseif motiontype == "rotate_forwardaxis" then
            local mq = w:singleton("main_queue", "camera_ref:in render_target:in")
            local dx, dy = dxdy(newx, newy, mq.render_target.view_rect)
            mouse_lastx, mouse_lasty = newx, newy
            iom.rotate_forward_vector(mq.camera_ref, dy, dx)
        elseif motiontype == "move_pan" then
            local mq = w:singleton("main_queue", "camera_ref:in render_target:in")
            local dx, dy = dxdy(newx, newy, mq.render_target.view_rect)
            if dx ~= 0 then
                dx = dx * 0.1
                iom.move_right(mq.camera_ref, dx)
            end

            if dy ~= 0 then
                dy = dy * 0.1
                iom.move_up(mq.camera_ref, dy)
            end
            mouse_lastx, mouse_lasty = newx, newy
        end
    end

end
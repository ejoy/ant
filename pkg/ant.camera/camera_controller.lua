local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc, mu = mathpkg.constant, mathpkg.util
local iom = ecs.require "ant.objcontroller|obj_motion"

local cc_sys = ecs.system "default_camera_controller"

local kb_mb             = world:sub {"keyboard"}
local mouse_mb          = world:sub {"mouse"}
local EventGesturePinch = world:sub {"gesture", "pinch"}
local EventGesturePan   = world:sub {"gesture", "pan"}

local viewat_change_mb      = world:sub{"camera_controller", "viewat"}
local move_speed_change_mb  = world:sub{"camera_controller", "move_speed"}
local inc_move_speed_mb     = world:sub{"camera_controller", "inc_move_speed"}
local dec_move_speed_mb     = world:sub{"camera_controller", "dec_move_speed"}
local move_speed_delta_change_mb = world:sub{"camera_controller", "move_speed_delta"}
local stop_camera_mb        = world:sub{"camera_controller", "stop"}

local mouse_lastx, mouse_lasty
local move_x, move_y, move_z
local move_speed_delta = 0.01
local move_speed = 1.0
local dxdy_speed = 2
local key_move_speed = 1.0
local init = false
local distance = 1
local baseDistance = 1
local zoomExponent = 2
local zoomFactor = 0.1
local pan_lastx, pan_lasty

local lookat = math3d.ref(math3d.vector(0, 0, 1))
--right up偏移
local last_ru = math3d.ref(math3d.vector(0, 0, 0))

local function calc_dxdy_speed()
    return move_speed * dxdy_speed
end

local function calc_key_speed()
    return move_speed * key_move_speed
end

local function check_update_control()
    --for _, _, pt in viewat_change_mb:unpack() do
    --    viewat = pt
    --end

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
    local dx = x / rect.w
    local dy = y / rect.h
    local speed = calc_dxdy_speed()
    return dx*speed, dy*speed
end

local stop_camera = false
local function check_stop_camera()
    for _, _, stop in stop_camera_mb:unpack() do
        stop_camera = stop
    end
    return stop_camera
end

local function calc_zoom_distance(dz)
    distance = distance - dz * zoomFactor
end

local function calc_cur_lookat()
    return math3d.mul(lookat,-distance)
end

local function camera_entity()
    local mq = w:first "main_queue camera_ref:in render_target:in"
    return world:entity(mq.camera_ref, "scene:in")
end

local action = {}

function action.scale(v)
    local ce <close> = camera_entity()
    calc_zoom_distance(v)
    local cur_lookat = calc_cur_lookat()
    iom.set_position(ce, math3d.add(last_ru, cur_lookat))
end

local pan_x, pan_y
function action.pan_reset(x, y)
    pan_x, pan_y = x, y
end

function action.pan(x, y)
    local dx, dy = x - pan_x, y - pan_y
    if dx == 0.0 and dy == 0.0 then
        return
    end

    local mq = w:first "main_queue camera_ref:in render_target:in"
    local ce<close> = world:entity(mq.camera_ref, "scene:in")
    pan_x, pan_y = x, y
    dx, dy = dxdy(dx, dy, mq.render_target.view_rect)
    local right = math3d.transform(ce.scene.r, mc.XAXIS, 0)
    right = math3d.normalize(right)
    local up = math3d.transform(ce.scene.r, mc.YAXIS, 0)
    up = math3d.normalize(up)
    last_ru.v = math3d.add(last_ru, math3d.mul(right, -dx*math.max(1.0,distance)), math3d.mul(up, dy*0.5*math.max(1.0, distance)))
    local cur_lookat = calc_cur_lookat()
    iom.set_position(ce, math3d.add(cur_lookat, last_ru))
end

function cc_sys:camera_set()
    if check_stop_camera() then
        return
    end
    if init == false then
        local mq = w:first("main_queue camera_ref:in render_target:in")
        local ce<close> = world:entity(mq.camera_ref, "scene:in camera:in")
        local t = ce.scene.t
        if mu.equal3d(t, mc.ZERO, 10e-6) then
            distance = 0.0
            lookat.v = math3d.inverse(math3d.todirection(ce.scene.r))
        else
            lookat.v = math3d.inverse(math3d.normalize(t))
            distance = math3d.length(t)
            calc_zoom_distance(0)
            local cur_lookat = calc_cur_lookat()
            iom.set_position(ce, math3d.add(last_ru.v, cur_lookat))
        end
        init = true
    end

    check_update_control()

    for _, _, e in EventGesturePinch:unpack() do
        action.scale(5 * e.velocity)
    end
    for _, _, e in EventGesturePan:unpack() do
        if e.state == "began" then
            pan_lastx, pan_lasty = e.x, e.y
            action.pan_reset(pan_lastx, pan_lasty)
        elseif e.state == "ended" then
            pan_lastx, pan_lasty = nil, nil
        else
            action.pan_reset(pan_lastx, pan_lasty)
            pan_lastx, pan_lasty = e.x, e.y
        end
        action.pan(e.x, e.y)
    end

    local rotatetype="rotate_point"
    for _, key, press, status in kb_mb:unpack() do
        local pressed = press == 1 or press == 2
        if key == "D" then
            move_x = pressed and -calc_key_speed() or nil
        elseif key == "A" then
            move_x = pressed and  calc_key_speed() or nil
        elseif key == "E" then
            move_y = pressed and -calc_key_speed() or nil
        elseif key == "Q" then
            move_y = pressed and  calc_key_speed() or nil
        elseif key == "S" then
            move_z = pressed and -calc_key_speed() or nil
        elseif key == "W" then
            move_z = pressed and  calc_key_speed() or nil
        end
        if status.SHIFT then
            rotatetype = "rotate_forwardaxis"
            if press == 0 then
                if key == "EQUALS" then --'+'
                    move_speed = move_speed + move_speed_delta
                elseif key == "MINUS" then --'-'
                    move_speed = move_speed - move_speed_delta
                end
            end
        else
            rotatetype = "rotate_point"
            local ce = camera_entity()
            if mu.equal3d(ce.scene.t, mc.ZERO, 10e-6) then
                print("camera position is equal to:%s, current target position is:%s, distance value is:%2f, can not rotate target point", 
                    math3d.tostring(ce.scene.t), math3d.tostring(mc.ZERO), distance)
                return
            end
        end
    end

    local newx, newy
    local motiontype
    for _, btn, state, x, y in mouse_mb:unpack() do
        if state == "DOWN" then
            newx, newy = x, y
            mouse_lastx, mouse_lasty = x, y
        elseif state == "MOVE" then
            newx, newy = x, y
        end

         if btn == "RIGHT"  then
            motiontype = assert(rotatetype)
         elseif btn == "MIDDLE" then
            motiontype = "move_pan"
        end
    end

    if move_x then
        local mq = w:first "main_queue camera_ref:in render_target:in"
        local ce<close> = world:entity(mq.camera_ref, "scene:in")
        move_x  = move_x / mq.render_target.view_rect.w * 30
        local right = math3d.transform(ce.scene.r, mc.XAXIS, 0)
        last_ru.v = math3d.add(last_ru, math3d.mul(right, -move_x*math.max(1.0, distance)))
        local cur_lookat = calc_cur_lookat()
        iom.set_position(ce, math3d.add(last_ru, cur_lookat))
    end

    if move_y then
        local mq = w:first "main_queue camera_ref:in render_target:in"
        local ce<close> = world:entity(mq.camera_ref, "scene:in")
        move_y = move_y / mq.render_target.view_rect.h * 30
        local up = math3d.transform(ce.scene.r, mc.YAXIS, 0)
        last_ru.v = math3d.add(last_ru, math3d.mul(up, -move_y*math.max(1.0,distance)))
        up = math3d.normalize(up)
        local cur_lookat = calc_cur_lookat()
        iom.set_position(ce, math3d.add(last_ru, cur_lookat))

    end

    if move_z then
        local ce<close> = camera_entity()
        calc_zoom_distance(move_z)
        local cur_lookat = calc_cur_lookat()
        iom.set_position(ce, math3d.add(last_ru, cur_lookat))
    end

    if motiontype and newx and newy then
        local mq = w:first "main_queue camera_ref:in render_target:in"
        local dx, dy = dxdy(newx-mouse_lastx, newy-mouse_lasty, mq.render_target.view_rect)
        if dx ~= 0.0 or dy ~= 0.0 then
            if motiontype == "rotate_point" then
                mouse_lastx, mouse_lasty = newx, newy
                local ce<close> = world:entity(mq.camera_ref, "scene:in")
                local ratio, newdir, pos = iom.rotate_around_point(ce, last_ru, 6*dy, 6*dx, ce.scene)
                distance = ratio
                lookat.v = newdir
                local cur_lookat = calc_cur_lookat()
                last_ru.v = math3d.sub(pos, cur_lookat)
            elseif motiontype == "rotate_forwardaxis" then
                mouse_lastx, mouse_lasty = newx, newy
                local ce<close> = world:entity(mq.camera_ref)
                iom.rotate_forward_vector(ce, dy, dx)
            elseif motiontype == "move_pan" then
                action.pan_reset(mouse_lastx, mouse_lasty)
                action.pan(newx, newy)
                mouse_lastx, mouse_lasty = newx, newy
            end
        end
    end

end
local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"
local mc=import_package "ant.math".constant
local iom = ecs.import.interface "ant.objcontroller|iobj_motion"

local cc_sys = ecs.system "default_camera_controller"

local kb_mb             = world:sub {"keyboard"}
local mouse_mb          = world:sub {"mouse"}
local mouse_wheel_mb    = world:sub {"mouse_wheel"}


local viewat_change_mb      = world:sub{"camera_controller", "viewat"}
local move_speed_change_mb  = world:sub{"camera_controller", "move_speed"}
local inc_move_speed_mb     = world:sub{"camera_controller", "inc_move_speed"}
local dec_move_speed_mb     = world:sub{"camera_controller", "dec_move_speed"}
local move_speed_delta_change_mb = world:sub{"camera_controller", "move_speed_delta"}

local stop_camera_mb        = world:sub{"camera_controller", "stop"}

local mouse_lastx, mouse_lasty
local move_x, move_y, move_z
local mouse_btn
local mouse_state
local move_speed_delta = 0.01
local move_speed = 1.0
local move_wheel_speed = 6
local dxdy_speed = 2
local key_move_speed = 1.0
local init=false

local distance=1
local baseDistance=1
local zoomExponent = 2
local zoomFactor = 0.01
local rotAroundY=0
local rotAroundX=0

local lookat = math3d.ref(math3d.vector(0, 0, 1))
--right up偏移
local lastru=math3d.ref(math3d.vector(0, 0, 0))
--lookat偏移
local lastl=math3d.ref(math3d.vector(0, 0, -1))

local function calc_dxdy_speed()
    return move_speed * dxdy_speed
end

local function calc_wheel_speed()
    return move_speed * move_wheel_speed
end

local function calc_key_speed()
    return move_speed * key_move_speed
end

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
    local dx = (x - mouse_lastx) / rect.w
    local dy = (y - mouse_lasty) / rect.h
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


function cc_sys:camera_usage()
    if check_stop_camera() then
        return
    end
    if init==false then
        local mq = w:first("main_queue camera_ref:in render_target:in")
        local ce<close> = w:entity(mq.camera_ref, "scene:in camera:in")
    
        local look=math3d.vector(math3d.index(ce.scene.t,1),math3d.index(ce.scene.t,2),math3d.index(ce.scene.t,3))
        lookat.v=math3d.normalize(look)
        lookat.v=math3d.inverse(lookat)
        local factor=(math3d.index(look,1)*math3d.index(look,1)+math3d.index(look,2)*math3d.index(look,2)+math3d.index(look,3)*math3d.index(look,3))^0.5
        distance=factor

        local zoomDistance=(distance/baseDistance)^(1.0/zoomExponent)
        zoomDistance=zoomDistance-0.001*zoomFactor
        zoomDistance=math.max(zoomDistance,0.0001)
        distance=(zoomDistance*zoomDistance)*baseDistance
        lastl.v=math3d.mul(lookat,-distance)
        iom.set_position(ce,math3d.add(lastru.v,lastl.v))
        init=true
    end

    check_update_control()
    local mq = w:first("main_queue camera_ref:in render_target:in")
    local ce<close> = w:entity(mq.camera_ref, "scene:update")
    for _, delta in mouse_wheel_mb:unpack() do     
        local d = delta > 0 and 5 or -5
        local zoomDistance=(distance/baseDistance)^(1.0/zoomExponent)
        zoomDistance=zoomDistance-d*zoomFactor
        zoomDistance=math.max(zoomDistance,0.0001)
        distance=(zoomDistance^zoomExponent)*baseDistance
        lastl.v=math3d.mul(lookat,-distance)
        iom.set_position(ce,math3d.add(lastru,lastl))
    end

    local rotatetype="rotate_point"
    for _, key, press, status in kb_mb:unpack() do
        local pressed = press == 1 or press == 2
        if key == "A" then
            move_x = pressed and -calc_key_speed() or nil
        elseif key == "D" then
            move_x = pressed and  calc_key_speed() or nil
        elseif key == "W" then
            move_y = pressed and -calc_key_speed() or nil
        elseif key == "S" then
            move_y = pressed and  calc_key_speed() or nil
        elseif key == "E" then
            move_z = pressed and -calc_key_speed() or nil
        elseif key == "Q" then
            move_z = pressed and  calc_key_speed() or nil
        end
        if status.SHIFT then
            rotatetype="rotate_forwardaxis"
            if press == 0 then
                if key == "EQUALS" then --'+'
                    move_speed = move_speed + move_speed_delta
                elseif key == "MINUS" then --'-'
                    move_speed = move_speed - move_speed_delta
                end
            end
        else
            rotatetype="rotate_point"
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

         if btn == "RIGHT"  then
            if rotatetype=="rotate_point"then
                motiontype = "rotate_point"
            else 
                motiontype="rotate_forwardaxis"
            end
         elseif btn == "MIDDLE" then
            motiontype = "move_pan"
        end
    end
           

    if move_x then
        move_x=move_x/mq.render_target.view_rect.w*30
        local right = math3d.transform(ce.scene.r, mc.XAXIS, 0)
        right=math3d.normalize(right)
        if distance<1 then
            lastru.v=math3d.add(lastru,math3d.mul(right,-move_x))
        else
            lastru.v=
                math3d.add(
                    lastru,
                    math3d.mul(right,-move_x*distance)
                )
        end
        iom.set_position(ce,math3d.add(lastru,lastl))

    end

    if move_y then
        move_y=move_y/mq.render_target.view_rect.h*30
        local up = math3d.transform(ce.scene.r, mc.YAXIS, 0)
        up=math3d.normalize(up)
        if distance<1 then
            lastru.v=math3d.add(lastru,math3d.mul(up,move_y))
        else
            lastru.v=math3d.add(lastru,math3d.mul(up,move_y*distance))
        end
        iom.set_position(ce,math3d.add(lastru,lastl))

    end

    if move_z then
        local zoomDistance=(distance/baseDistance)^(1.0/zoomExponent)
        zoomDistance=zoomDistance-move_z*zoomFactor
        zoomDistance=math.max(zoomDistance,0.0001)
        distance=(zoomDistance*zoomDistance)*baseDistance
        lastl.v=math3d.mul(lookat,-distance)
        iom.set_position(ce,math3d.add(lastru,lastl))
    end

    if motiontype and newx and newy then
        local dx, dy = dxdy(newx, newy, mq.render_target.view_rect)
        if dx ~= 0.0 or dy ~= 0.0 then
            if motiontype == "rotate_point" then
                 mouse_lastx, mouse_lasty = newx, newy
                local ratio,newdir,pos=iom.rotate_around_point2(ce, lastru,6*dy, 6*dx,ce.scene)
                distance=ratio
                lookat.v=newdir
                lastl.v=math3d.mul(newdir,-distance)
                lastru.v=math3d.sub(pos,lastl)
            elseif motiontype == "rotate_forwardaxis" then
                mouse_lastx, mouse_lasty = newx, newy
                iom.rotate_forward_vector(ce, dy, dx)
            elseif motiontype == "move_pan" then
                local right = math3d.transform(ce.scene.r, mc.XAXIS, 0)
                right=math3d.normalize(right)
                local up = math3d.transform(ce.scene.r, mc.YAXIS, 0)
                up=math3d.normalize(up)

                if distance<1 then

                    lastru.v =
                        math3d.add(
                            lastru,
                            math3d.mul(right,-dx),
                            math3d.mul(up,dy*0.5)
                        )
                                 else
                    lastru.v=
                        math3d.add(
                            lastru,
                            math3d.mul(right,-dx*distance),
                            math3d.mul(up,dy*0.5*distance)
                        )        
                end
                iom.set_position(ce,math3d.add(lastl,lastru))    
                mouse_lastx, mouse_lasty = newx, newy
            end
        end
    end

end
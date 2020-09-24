local ecs = ...
local world = ecs.world
local rhwi = import_package 'ant.render'.hwi
local utils = require "mathutils"(world)
local m = ecs.system 'input_system'
local event_mouse = world:sub {"mouse"}
local event_mouse_wheel = world:sub {"mouse_wheel"}
local last_mouse
local last_x, last_y
local event_keyboard = world:sub{"keyboard"}

function m:data_changed()
    for _,what,state,x,y in event_mouse:unpack() do
        local vx, vy = utils.mouse_pos_in_view(x, y)
        --print(vx, vy)
        if vx and vy then
            if state == "MOVE" then
                world:pub {"mousemove", what, vx, vy}
            end
            if state == "DOWN" then
                last_x, last_y = vx, vy
                last_mouse = what
                world:pub {"mousedown", what, vx, vy}
            elseif state == "MOVE" and last_mouse == what then
                local dpiX, dpiY = rhwi.dpi()
                local dx, dy = (vx - last_x) / dpiX, (vy - last_y) / dpiY
                if what == "LEFT" or what == "RIGHT" then
                    world:pub { "mousedrag", what, vx, vy, dx, dy }
                end
                last_x, last_y = vx, vy
            elseif state == "UP" then
                world:pub {"mouseup", what, vx, vy}
            end
        end
    end
    for _, delta, x, y in event_mouse_wheel:unpack() do
        local vx, vy = utils.mouse_pos_in_view(x, y)
        if vx and vy then
            world:pub { "camera", "zoom", -delta }
        end
    end
    for _, key, press, state in event_keyboard:unpack() do
        if key == "W" and press == 2 then

        elseif key == "S" and press == 2 then

		elseif key == "A" and press == 2 then
			
		elseif key == "D" and press == 2 then
			
        end
        --print(key, press)
	end
end

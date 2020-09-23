local ecs = ...
local world = ecs.world
local rhwi = import_package 'ant.render'.hwi
local global_data = require "common.global_data"
local m = ecs.system 'input_system'

local event_mouse = world:sub {"mouse"}
local event_mouse_wheel = world:sub {"mouse_wheel"}
local last_mouse
local last_x, last_y
local event_keyboard = world:sub{"keyboard"}

local function is_in_view(x, y)
    if not global_data.viewport then
        return false
    end
    local xinview = x - global_data.viewport.x
    local yinview = y - global_data.viewport.y
    return xinview > 0 and xinview < global_data.viewport.w and yinview > 0 and yinview < global_data.viewport.h
end
function m:data_changed()
    for _,what,state,x,y in event_mouse:unpack() do
        if is_in_view(x, y) then
            if state == "MOVE" then
                world:pub {"mousemove", what, x, y}
            end
            if state == "DOWN" then
                last_x, last_y = x, y
                last_mouse = what
                world:pub {"mousedown", what, x, y}
            elseif state == "MOVE" and last_mouse == what then
                local dpiX, dpiY = rhwi.dpi()
                local dx, dy = (x - last_x) / dpiX, (y - last_y) / dpiY
                if what == "LEFT" or what == "RIGHT" then
                    world:pub { "mousedrag", what, x, y, dx, dy }
                end
                last_x, last_y = x, y
            elseif state == "UP" then
                world:pub {"mouseup", what, x, y}
            end
        end
    end
    for _, delta, x, y in event_mouse_wheel:unpack() do
        if is_in_view(x, y) then
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

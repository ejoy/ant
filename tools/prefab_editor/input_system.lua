local ecs = ...
local world = ecs.world
local rhwi = import_package 'ant.render'.hwi
local global_data = require "common.global_data"
local m = ecs.system 'input_system'

local eventMouse = world:sub {"mouse"}
local eventMouseWheel = world:sub {"mouse_wheel"}
local lastMouse
local lastX, lastY
local keypress_mb = world:sub{"keyboard"}

local function is_in_view(x, y)
    if not global_data.viewport then
        return x, y
    end
    local xinview = x - global_data.viewport.x
    local yinview = y - global_data.viewport.y
    return xinview > 0 and xinview < global_data.viewport.w and yinview > 0 and yinview < global_data.viewport.h
end
function m:data_changed()
    for _,what,state,x,y in eventMouse:unpack() do
        if is_in_view(x, y) then
            if state == "MOVE" then
                world:pub {"mousemove", what, x, y}
            end
            if state == "DOWN" then
                lastX, lastY = x, y
                lastMouse = what
                world:pub {"mousedown", what, x, y}
            elseif state == "MOVE" and lastMouse == what then
                local dpiX, dpiY = rhwi.dpi()
                local dx, dy = (x - lastX) / dpiX, (y - lastY) / dpiY
                if what == "LEFT" or what == "RIGHT" then
                    world:pub { "mousedrag", what, x, y, dx, dy }
                end
                lastX, lastY = x, y
            elseif state == "UP" then
                world:pub {"mouseup", what, x, y}
            end
        end
    end
    for _, delta, x, y in eventMouseWheel:unpack() do
        if is_in_view(x, y) then
            world:pub { "camera", "zoom", -delta }
        end
    end
    for _, key, press, state in keypress_mb:unpack() do
        if key == "W" and press == 2 then

        elseif key == "S" and press == 2 then

		elseif key == "A" and press == 2 then
			
		elseif key == "D" and press == 2 then
			
        end
        --print(key, press)
	end
end

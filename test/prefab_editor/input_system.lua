local ecs = ...
local world = ecs.world
local rhwi = import_package 'ant.render'.hwi

local m = ecs.system 'input_system'

local eventMouse = world:sub {"mouse"}
local eventMouseWheel = world:sub {"mouse_wheel"}
local lastMouse
local lastX, lastY
local keypress_mb = world:sub{"keyboard"}

function m:data_changed()
    for _,what,state,x,y in eventMouse:unpack() do
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
            -- if what == "LEFT" then
            --     world:pub { "camera", "pan", dx*kPanSpeed, dy*kPanSpeed }
            -- elseif what == "RIGHT" then
            --     world:pub { "camera", "rotate", dx*kRotationSpeed, dy*kRotationSpeed }
            -- end
            if what == "LEFT" or what == "RIGHT" then
                world:pub { "mousedrag", what, x, y, dx, dy }
            end
            lastX, lastY = x, y
        elseif state == "UP" then
            world:pub {"mouseup", what, x, y}
        end
    end
    for _,delta in eventMouseWheel:unpack() do
        world:pub { "camera", "zoom", -delta }
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

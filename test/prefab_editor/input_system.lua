local ecs = ...
local world = ecs.world
local rhwi = import_package 'ant.render'.hwi

local m = ecs.system 'input_system'

local eventMouse = world:sub {"mouse"}
local eventMouseWheel = world:sub {"mouse_wheel"}
local kRotationSpeed <const> = 1
local kZoomSpeed <const> = 1
local kPanSpeed <const> = 0.5
local kWheelSpeed <const> = 0.5
local lastMouse
local lastX, lastY

function m:data_changed()
    for _,what,state,x,y in eventMouse:unpack() do
        if state == "DOWN" then
            lastX, lastY = x, y
            lastMouse = what
        elseif state == "MOVE" and lastMouse == what then
            local dpiX, dpiY = rhwi.dpi()
            local dx, dy = (x - lastX) / dpiX, (y - lastY) / dpiY
            if what == "LEFT" then
                world:pub { "camera", "pan", dx*kPanSpeed, dy*kPanSpeed }
            elseif what == "RIGHT" then
                world:pub { "camera", "rotate", dx*kRotationSpeed, dy*kRotationSpeed }
            end
            lastX, lastY = x, y
        end
    end
    for _,delta in eventMouseWheel:unpack() do
        world:pub { "camera", "zoom", -delta*kWheelSpeed }
    end
end

local ecs = ...
local world = ecs.world
local rhwi  = import_package "ant.hwi"
local utils = ecs.require "mathutils"
local imgui = require "imgui"
local m     = ecs.system 'input_system'
local event_mouse = world:sub {"mouse"}
local event_mouse_wheel = world:sub {"mouse_wheel"}
local event_keyboard = world:sub{"keyboard"}
local last_mouse
local last_vx, last_vy
local last_wx, last_wy

function m:input_filter()
    for _,what,state,x,y in event_mouse:unpack() do
        local vx, vy = x,y
        if vx and vy then
            if state == "DOWN" then
                last_vx, last_vy = vx, vy
                last_mouse = what
                world:pub {"mousedown", what, vx, vy}
            elseif state == "MOVE" and last_mouse == what then
                local dpiX, dpiY = rhwi.dpi()
                local dx, dy = (vx - last_vx) / dpiX, (vy - last_vy) / dpiY
                if what == "LEFT" or what == "RIGHT" or what == "MIDDLE" then
                    world:pub { "mousedrag", what, vx, vy, dx, dy }
                end
                last_vx, last_vy = vx, vy
            elseif state == "UP" then
                world:pub {"mouseup", what, vx, vy}
            else
                world:pub {"mousemove", what, vx, vy}
            end
        end
    end
end

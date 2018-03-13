local ecs = ...
local world = ecs.world
local ru = require "render.util"
local bgfx = require "bgfx"
--[@
local present_sys = ecs.system "present"

present_sys.depend "entity_rendering"

function present_sys:update() 
    bgfx.frame()
end
--@]
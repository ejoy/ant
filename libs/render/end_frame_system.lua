local ecs = ...
local world = ecs.world
local ru = require "render.util"
local bgfx = require "bgfx"

--[@
ecs.component "frame_num" {}
--@]

--[@
local end_frame_sys = ecs.system "end_frame"

end_frame_sys.singleton "frame_num"
end_frame_sys.depend "entity_rendering"
end_frame_sys.depend "pickup_system"

function end_frame_sys:update() 
    local frame_num = self.frame_num
    frame_num.current = bgfx.frame()
end
--@]
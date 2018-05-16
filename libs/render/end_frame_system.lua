local ecs = ...
local bgfx = require "bgfx"

--[@
ecs.component "frame_stat" {}
--@]

--[@
local end_frame_sys = ecs.system "end_frame"

end_frame_sys.singleton "frame_stat"

function end_frame_sys:update() 
    local stat = self.frame_stat
    stat.frame_num = bgfx.frame()
end
--@]
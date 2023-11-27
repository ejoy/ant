local ecs   = ...
local world = ecs.world
local w     = world.w

local fbrt_sys = ecs.system "framebuffer_ratio_test_system"
local kb_mb = world:sub{"keyboard"}

function fbrt_sys.data_changed()
    for _, key, press in kb_mb:unpack() do
        if key == "M" and press == 0 then
            local irender = ecs.require "ant.render|render_system.render"
            local whichratio = "scene_ratio"    -- "ratio"
            local r = irender.get_framebuffer_ratio(whichratio)
            irender.set_framebuffer_ratio(whichratio, r - 0.1)
        end
    end
end
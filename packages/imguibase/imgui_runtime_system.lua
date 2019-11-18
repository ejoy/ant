local ecs = ...
local world = ecs.world
local imgui = require "imgui"

local renderpkg = import_package "ant.render"
local renderutil= renderpkg.util
local viewidmgr = renderpkg.viewidmgr
local fbmgr = renderpkg.fbmgr

local imgui_runtime_system =  ecs.system "imgui_runtime_system"
local timer = import_package "ant.timer"


function imgui_runtime_system:update()
    local frame_time = timer.deltatime/1000
    if frame_time <= 0.0 then
        frame_time = 1.0/60
    end
    imgui.begin_frame(frame_time)
    world:update_func("on_gui")()
    local vid = imgui.viewid()
    renderutil.update_frame_buffer_view(vid, fbmgr.get_fb_idx(vid))
    imgui.end_frame()
end

-- test
-- function imgui_runtime_system:on_gui()
--     local windows = imgui.windows
--     local widget = imgui.widget
--     local flags = imgui.flags
--     windows.SetNextWindowSizeConstraints(000, 000, 200, 200)
--     windows.Begin("TestGui")
--     widget.Text("Helloworld")
--     windows.End()
-- end


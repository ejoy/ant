local ecs = ...
local world = ecs.world
local imgui = require "imgui"

local renderpkg = import_package "ant.render"
local renderutil= renderpkg.util
local viewidmgr = renderpkg.viewidmgr
local fbmgr = renderpkg.fbmgr

local imgui_runtime_system =  ecs.system "imgui_runtime_system"

function imgui_runtime_system:update()
    imgui.begin_frame(1/60)
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


local ecs = ...
local world = ecs.world
local imgui = import_package "ant.imgui".imgui
local imgui_runtime_system =  ecs.system "imgui_runtime_system"

function imgui_runtime_system:update()
    imgui.begin_frame(1/60)
    world:update_func("on_gui")()
    imgui.end_frame()
end


-- function imgui_runtime_system:on_gui()
--     local windows = imgui.windows
--     local widget = imgui.widget
--     local flags = imgui.flags
--     windows.SetNextWindowSizeConstraints(000, 000, 200, 200)
--     windows.Begin("TestGui")
--     widget.Text("Helloworld")
--     windows.End()
-- end


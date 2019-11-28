local ecs = ...
local world = ecs.world
local imgui = require "imgui"
local imgui_ant = require "imgui.ant"

local renderpkg = import_package "ant.render"
local renderutil= renderpkg.util
local fbmgr = renderpkg.fbmgr

local imgui_runtime_system =  ecs.system "imgui_runtime_system"
local timer = import_package "ant.timer"

local function defer(f)
    local toclose = setmetatable({}, { __close = f })
    return function (_, w)
        if not w then
            return toclose
        end
    end, nil, nil, toclose
end

local function imgui_frame(time)
    imgui.begin_frame(time)
    return defer(function()
        imgui.end_frame()
    end)
end

function imgui_runtime_system:update()
    local frame_time = timer.deltatime/1000
    if frame_time <= 0.0 then
        frame_time = 1.0/60
    end

    for _ in imgui_frame(frame_time) do
        world:update_func("on_gui")()
        local vid = imgui_ant.viewid()
        renderutil.update_frame_buffer_view(vid, fbmgr.get_fb_idx(vid))
    end
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


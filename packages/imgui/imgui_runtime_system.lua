local ecs = ...
local world = ecs.world

local imgui     = require "imgui"
local timer     = world:interface "ant.timer|timer"
local imgui_sys = ecs.system "imgui_system"

function imgui_sys:ui_start()
	local delta = timer.delta()
    imgui.NewFrame(delta / 1000)
    imgui.UpdateIO()
end

function imgui_sys:ui_end()
    imgui.Render()
end

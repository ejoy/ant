local ecs = ...
local world = ecs.world

local imgui       = require "imgui"
local platform    = require "platform"
local imguiIO     = imgui.IO
local font        = imgui.font
local Font        = platform.font
local timer       = world:interface "ant.timer|timer"

local imgui_sys = ecs.system "imgui_system"

local function hookEvent()
	world:signal_hook("mouse_wheel", function(x, y, delta)
		return imguiIO.WantCaptureMouse
	end)
	world:signal_hook("mouse", function(x, y, what, state)
		return imguiIO.WantCaptureMouse
	end)
	world:signal_hook("keyboard", function(key, press, state)
		return imguiIO.WantCaptureKeyboard
	end)
end

local function glyphRanges(t)
	assert(#t % 2 == 0)
	local s = {}
	for i = 1, #t do
		s[#s+1] = ("<I4"):pack(t[i])
	end
	s[#s+1] = "\x00\x00\x00"
	return table.concat(s)
end

function imgui_sys:init()
	hookEvent()
	if platform.OS == "Windows" then
		font.Create {
			{ Font "Segoe UI Emoji" , 18, glyphRanges { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }},
			{ Font "黑体" , 18, glyphRanges { 0x0020, 0xFFFF }},
		}
	elseif platform.OS == "macOS" then
		font.Create { { Font "华文细黑" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	else -- iOS
		font.Create { { Font "Heiti SC" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	end
end

function imgui_sys:exit()
    imgui.Destroy()
end

function imgui_sys:post_init()
end


function imgui_sys:ui_start()
	local delta = timer.delta()
    imgui.NewFrame(delta / 1000)
    imgui.UpdateIO()
end

function imgui_sys:ui_end()
    imgui.Render()
end

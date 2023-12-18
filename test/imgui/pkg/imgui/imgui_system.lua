local ecs = ...
local world = ecs.world
local w = world.w

local imgui = require "imgui"
local platform = require "bee.platform"
local rhwi = import_package "ant.hwi"
local assetmgr = import_package "ant.asset"
local PM = require "programan.client"

local m = ecs.system 'imgui_system'

local event = {}

function event.size()
end

function event.dropfiles(files)
end

local viewidcount = 0
local imgui_viewids = {}

for i = 1, 16 do
	imgui_viewids[i] = rhwi.viewid_generate("imgui_eidtor" .. i, "uiruntime")
end

function event.viewid()
	if viewidcount >= #imgui_viewids then
		error(("imgui viewid range exceeded, max count:%d"):format(#imgui_viewids))
	end
	viewidcount = viewidcount + 1
	return imgui_viewids[viewidcount]
end

function m:init()
	imgui.v2.CreateContext(event)
	imgui.v2.InitPlatform(rhwi.native_window())

	local imgui_font = assetmgr.load_material "/pkg/ant.imgui/materials/font.material"
	local imgui_image = assetmgr.load_material "/pkg/ant.imgui/materials/image.material"
	assetmgr.material_mark(imgui_font.fx.prog)
	assetmgr.material_mark(imgui_image.fx.prog)
	imgui.InitRender(
		PM.program_get(imgui_font.fx.prog),
		PM.program_get(imgui_image.fx.prog),
		imgui_font.fx.uniforms.s_tex.handle,
		imgui_image.fx.uniforms.s_tex.handle
	)

	local Font = imgui.font.SystemFont
	local function glyphRanges(t)
		assert(#t % 2 == 0)
		local s = {}
		for i = 1, #t do
			s[#s+1] = ("<I4"):pack(t[i])
		end
		s[#s+1] = "\x00\x00\x00"
		return table.concat(s)
	end
	if platform.os == "windows" then
		imgui.font.Create {
			{ Font "Segoe UI Emoji" , 18, glyphRanges { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }},
			{ Font "黑体" , 18, glyphRanges { 0x0020, 0xFFFF }},
		}
	elseif platform.os == "macos" then
		imgui.font.Create { { Font "华文细黑" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	elseif platform.os == "ios" then
		imgui.font.Create { { Font "Heiti SC" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	else
		error("unknown os:" .. platform.os)
	end
end

function m:exit()
	imgui.v2.DestroyContext()
end

local TouchEvent = world:sub { "touch" }
local GesturePinchEvent = world:sub { "gesture", "pinch" }

function m:start_frame()
	for _, e in TouchEvent:unpack() do
		if e.state == "began" then
			imgui.v2.AddMouseButtonEvent(0, true)
		elseif e.state == "ended" then
			imgui.v2.AddMouseButtonEvent(0, false)
		end
	end
	for _, _, e in GesturePinchEvent:unpack() do
		imgui.v2.AddMouseWheelEvent(e.velocity, e.velocity)
	end
	imgui.v2.NewFrame()
end

function m:end_frame()
	imgui.Render()
end

local ecs = ...
local world = ecs.world
local w = world.w

local imgui = require "imgui"
local platform = require "bee.platform"
local rhwi = import_package "ant.hwi"
local assetmgr = import_package "ant.asset"
local inputmgr = import_package "ant.inputmgr"
local PM = require "programan.client"

local m = ecs.system 'imgui_system'

local event = {}

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
	imgui.CreateContext()
	imgui.io.ConfigFlags = imgui.flags.Config {
		"NavEnableKeyboard",
		--"ViewportsEnable",
		"DockingEnable",
		"NavNoCaptureKeyboard",
		"DpiEnableScaleViewports",
		"DpiEnableScaleFonts",
	}
	imgui.SetCallback(event)
	imgui.InitPlatform(rhwi.native_window())

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
		imgui.font.Create { { Font "苹方-简" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	elseif platform.os == "ios" then
		imgui.font.Create { { Font "Heiti SC" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	else
		error("unknown os:" .. platform.os)
	end
    inputmgr:enable_imgui()
end

function m:exit()
	imgui.DestroyRenderer()
	imgui.DestroyPlatform()
	imgui.DestroyContext()
end

function m:start_frame()
	imgui.NewFrame()
end

function m:end_frame()
	imgui.Render()
end

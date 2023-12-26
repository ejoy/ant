local ecs = ...

local platform = require "bee.platform"
local imgui = import_package "ant.imgui"
local rhwi = import_package "ant.hwi"
local assetmgr = import_package "ant.asset"
local inputmgr = import_package "ant.inputmgr"
local PM = require "programan.client"

local m = ecs.system 'imgui_system'

function m:init_system()
	imgui.CreateContext()
	imgui.io.ConfigFlags = imgui.flags.Config {
		"NavEnableKeyboard",
		"DockingEnable",
		"NavNoCaptureKeyboard",
		"DpiEnableScaleViewports",
		"DpiEnableScaleFonts",
	}
	imgui.InitPlatform(rhwi.native_window())

	local imgui_font = assetmgr.load_material "/pkg/ant.imgui/materials/font.material"
	local imgui_image = assetmgr.load_material "/pkg/ant.imgui/materials/image.material"
	assetmgr.material_mark(imgui_font.fx.prog)
	assetmgr.material_mark(imgui_image.fx.prog)
	local viewId = rhwi.viewid_generate("imgui_eidtor" .. 1, "uiruntime")
	imgui.InitRender {
		fontProg = PM.program_get(imgui_font.fx.prog),
		imageProg = PM.program_get(imgui_image.fx.prog),
		fontUniform = imgui_font.fx.uniforms.s_tex.handle,
		imageUniform = imgui_image.fx.uniforms.s_tex.handle,
		viewIdPool = { viewId },
	}
	if platform.os == "windows" then
		imgui.FontAtlasAddFont {
			SystemFont = "Segoe UI Emoji",
			SizePixels = 18,
			GlyphRanges = { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }
		}
		imgui.FontAtlasAddFont {
			SystemFont = "黑体",
			SizePixels = 18,
			GlyphRanges = { 0x0020, 0xFFFF }
		}
	elseif platform.os == "macos" then
		imgui.FontAtlasAddFont {
			SystemFont = "华文细黑",
			SizePixels = 18,
			GlyphRanges = { 0x0020, 0xFFFF }
		}
	else -- iOS
		imgui.FontAtlasAddFont {
			SystemFont = "Heiti SC",
			SizePixels = 18,
			GlyphRanges = { 0x0020, 0xFFFF }
		}
	end
	inputmgr:enable_imgui()
end

function m:init_world()
	imgui.FontAtlasBuild()
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

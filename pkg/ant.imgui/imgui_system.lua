local ecs = ...
local world = ecs.world

local platform = require "bee.platform"
local ImGui = require "imgui"
local ImGuiBackend = require "imgui.backend"
local rhwi = import_package "ant.hwi"
local assetmgr = import_package "ant.asset"
local window = import_package "ant.window"
local PM = require "programan.client"
local viewIdPool = require "viewid_pool"

local m = ecs.system 'imgui_system'

function m:init_system()
	ImGui.CreateContext()
	ImGuiBackend.Init()
	local ConfigFlags = {
		"NavEnableKeyboard",
		"DockingEnable",
		"NavNoCaptureKeyboard",
		"NoMouseCursorChange",
	}
	if platform.os == "windows" then
		ConfigFlags[#ConfigFlags+1] = "DpiEnableScaleFonts"
	end
	ImGui.GetIO().ConfigFlags = ImGui.ConfigFlags(ConfigFlags)
	ImGuiBackend.PlatformInit(rhwi.native_window())

	local imgui_font = assetmgr.load_material "/pkg/ant.imgui/materials/font.material"
	local imgui_image = assetmgr.load_material "/pkg/ant.imgui/materials/image.material"
	assetmgr.material_mark(imgui_font.fx.prog)
	assetmgr.material_mark(imgui_image.fx.prog)
	ImGuiBackend.RenderInit {
		fontProg = PM.program_get(imgui_font.fx.prog),
		imageProg = PM.program_get(imgui_image.fx.prog),
		fontUniform = imgui_font.fx.uniforms.s_tex.handle,
		imageUniform = imgui_image.fx.uniforms.s_tex.handle,
		viewIdPool = viewIdPool,
	}
	world:enable_imgui()
end

function m:init_world()
    ImGuiBackend.RenderCreateFontsTexture()
end

local event_save_layout = world:sub {"save_layout"}
function m:exit()
	world:disable_imgui()
	for _, path in event_save_layout:unpack() do
		local setting = ImGui.SaveIniSettingsToMemory()
		local wf = assert(io.open(path, "wb"))
		wf:write(setting)
		wf:close()
	end
	ImGuiBackend.RenderDestroy()
	ImGuiBackend.PlatformDestroy()
	ImGui.DestroyContext()
end

local last_cursor = 0

function m:start_frame()
	local cursor = ImGui.GetMouseCursor()
	if last_cursor ~= cursor then
		last_cursor = cursor
		window.set_cursor(cursor)
	end
	ImGuiBackend.PlatformNewFrame()
	ImGui.NewFrame()
end

function m:end_frame()
	ImGui.Render()
	ImGuiBackend.RenderDrawData()
	ImGui.UpdatePlatformWindows()
	ImGui.RenderPlatformWindowsDefault()
end

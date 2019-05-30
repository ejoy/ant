local native = require "window.native"
local window = require "window"
local bgfx = require "bgfx"
local imgui = require "imgui"
local platform = require "platform"
local hw = import_package "ant.render".hardware_interface
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local font = imgui.font
local Font = platform.font
local native_window

local callback = {
	mouse_move = imgui.mouse_move,
	mouse_wheel = imgui.mouse_wheel,
	mouse_click = imgui.mouse_click,
	keyboard = imgui.key_state,
	char = imgui.input_char,
	error = print
}

local function Shader(shader)
	local shader_mgr = import_package "ant.render".shader_mgr
	local uniforms = {}
	shader.prog = shader_mgr.programLoad(assert(shader.vs), assert(shader.fs), uniforms)
	assert(shader.prog ~= nil)
	shader.uniforms = uniforms
	return shader
end

function callback.init(nwh, context, width, height)
	native_window = nwh

	imgui.create(nwh)

	hw.init {
		nwh = nwh,
		context = context,
	--	renderer = "DIRECT3D9",
	--	renderer = "OPENGL",
		width = width,
		height = height,
	--	reset = "v",
	}

	local ocornut_imgui = Shader {
		vs = "//ant.ImguiSample/shader/vs_ocornut_imgui",
		fs = "//ant.ImguiSample/shader/fs_ocornut_imgui",
	}
	local imgui_image = Shader {
		vs = "//ant.ImguiSample/shader/vs_imgui_image",
		fs = "//ant.ImguiSample/shader/fs_imgui_image",
	}

	imgui.viewid(255);
	imgui.program(
		ocornut_imgui.prog,
		imgui_image.prog,
		ocornut_imgui.uniforms.s_tex.handle,
		imgui_image.uniforms.u_imageLodEnabled.handle
	)
	imgui.resize(width, height)
	imgui.keymap(native.keymap)
	window.set_ime(imgui.ime_handle());

	bgfx.set_view_rect(0, 0, 0, width, height)
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
--	bgfx.set_debug "ST"

	font.Create {
		platform.OS == "Windows"
		and { Font "黑体" ,    18, "\x20\x00\xFF\xFF\x00"}
		or  { Font "华文细黑" , 18, "\x20\x00\xFF\xFF\x00"},
	}
end

function callback.size(width,height,type)
	imgui.resize(width,height)
	hw.reset(nil, width, height)
	bgfx.set_view_rect(0, 0, 0, width, height)
end

local editbox = {
	flags = flags.InputText { "CallbackCharFilter", "CallbackHistory", "CallbackCompletion" },
}

function editbox:filter(c)
	if c == 65 then
		-- filter 'A'
		return
	end
	return c
end

local t = 0
function editbox:up()
	t = t - 1
	return tostring(t)
end

function editbox:down()
	t = t + 1
	return tostring(t)
end

function editbox:tab(pos)
	t = t + 1
	return tostring(t)
end

local editfloat = {
	0,
	step = 0.1,
	step_fast = 10,
}

local checkbox = {}

local combobox = { "B" }

local lines = { 1,2,3,2,1 }

local test_window = {
	id = "Test",
	open = true,
	flags = flags.Window { "MenuBar" },	-- "NoClosed"
}

local function run_window(wnd)
	if not wnd.open then
		return
	end
	local touch, open = windows.Begin(wnd.id, wnd.flags)
	if touch then
		wnd:update()
		windows.End()
		wnd.open = open
	end
end

local lists = { "Alice", "Bob" }

local tab_noclosed = flags.TabBar { "NoClosed" }

function test_window:update()
	self:menu()
	if windows.BeginTabBar "tab_bar" then
		if windows.BeginTabItem ("Tab1",tab_noclosed) then
			self:tab_update()
			windows.EndTabItem()
		end
		if windows.BeginTabItem ("Tab2",tab_noclosed) then
			if widget.Button "Save Ini" then
				print(util.SaveIniSettings())
			end
			if windows.BeginPopupModal "Popup window" then
				widget.Text "Pop up"
				windows.EndPopup()
			end
			if widget.Button "Popup" then
				windows.OpenPopup "Popup window"
			end
			windows.EndTabItem()
		end
		windows.EndTabBar()
	end
end

function test_window:menu()
	if widget.BeginMenuBar() then
		widget.MenuItem("M1")
		widget.MenuItem("M2")
		widget.EndMenuBar()
	end
end

function test_window:tab_update()
	if widget.Button "Open File" then
		local dialog = require "filedialog"
		local ok, res = dialog.open {
			Owener = native_window,
			Title = "Test",
			FileTypes = { "All Files (*.*)", "*.*" }
		}
		if ok then
			for _, path in ipairs(res) do
				print("Open:", path)
			end
		else
			print(res)
		end
	end
	widget.SmallButton "Small"
	if widget.Checkbox("Checkbox", checkbox) then
		print("Click Checkbox", checkbox[1])
	end
	if widget.InputText("Edit", editbox) then
		print(editbox.text)
	end
	widget.InputFloat("InputFloat", editfloat)
	widget.Text("Hello World", 1,0,0)
	if widget.BeginCombo( "Combo", combobox ) then
		widget.Selectable("A", combobox)
		widget.Selectable("B", combobox)
		widget.Selectable("C", combobox)
		widget.EndCombo()
	end
	if widget.TreeNode "TreeNodeA" then
		widget.TreePop()
	end
	if widget.TreeNode "TreeNodeB" then
		widget.TreePop()
	end
	if widget.TreeNode "TreeNodeC" then
		widget.TreePop()
	end

	widget.PlotLines("lines", lines)
	widget.PlotHistogram("histogram", lines)

	if widget.ListBox("##list",lists) then
		print(lists.current)
	end
end

local function update_ui()
	windows.SetNextWindowSizeConstraints(300, 300, 500, 500)
	run_window(test_window)
end

function callback.update()
	imgui.begin_frame(1/60)
	update_ui()
	imgui.end_frame()

	bgfx.touch(0)

--	bgfx.dbg_text_clear()
--	bgfx.dbg_text_print(0, 1, 0xf, "Color can be changed with ANSI \x1b[9;me\x1b[10;ms\x1b[11;mc\x1b[12;ma\x1b[13;mp\x1b[14;me\x1b[0m code too.");

	bgfx.frame()
end

function callback.exit()
	print("Exit")
	imgui.destroy()
	hw.shutdown()
end

window.register(callback)

native.create(1024, 768, "Hello")
native.mainloop()

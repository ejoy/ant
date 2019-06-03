local ecs = ...

ecs.import 'ant.basic_components'


local imgui = require "imgui"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local native_window

local imgui_system = ecs.system "imgui_system"

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
			Owner = native_window,
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

function imgui_system:update()
    imgui.begin_frame(1/60)
    update_ui()
    imgui.end_frame()
end


--TODO
local world = ecs.world

ecs.import "ant.render"

local ms = import_package "ant.math".stack
local cu = import_package "ant.render".components
local ru = import_package "ant.render".util

imgui_system.depend "render_system"

function imgui_system:init()
	ru.create_render_queue_entity(world, world.args.fb_size, ms({1, 1, -1}, "inT"), {5, 5, -5}, "main_view")
	cu.create_grid_entity(world, "grid")
end

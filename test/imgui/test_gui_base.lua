local imgui   = import_package "ant.imgui".imgui
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum


local GuiBase = import_package "ant.imgui".gui_base

local TestGuiBase = class("TestGuiBase",GuiBase)


TestGuiBase.GuiName = "TestGuiBase"

function TestGuiBase:_init()
    GuiBase._init(self)
    self.title = "test windows"
    self.id = "Test"
    self.title_id = self.title.."###"..self.id
    self.win_flags = flags.Window { "MenuBar" }
    self._is_opened = true
end

local tab_noclosed = flags.TabBar { "NoClosed" }
function TestGuiBase:on_update()
    windows.PushStyleVar( enum.StyleVar.WindowPadding,0,0)
    if widget.BeginMenuBar() then
        if widget.MenuItem("hello") then
            -- local scene_control = require "scene_control"
            -- scene_control.test_new_world()
            print("hello")
        end
        
        widget.MenuItem("M2")
        widget.EndMenuBar()
    end
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
    windows.PopStyleVar()
end

local editfloat = {
    0,
    step = 0.1,
    step_fast = 10,
}
local checkbox = {}
local combobox = { "B" }
local lines = { 1,2,3,2,1 }
local lists = { "Alice", "Bob" }
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


function TestGuiBase:tab_update()
    windows.PushStyleColor(enum.StyleCol.Button,1,1,1,1)
    if widget.Button "Test" then
        print("test1")
    end
    windows.PopStyleColor()

    if widget.Button "Test" then
        print("test2")
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
        if widget.TreeNode "TreeNodeAA" then
            widget.TreePop()
        end
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


--main menu
function TestGuiBase:get_mainmenu()
    local parent_path_1 = {"MainTest1"}
    local parent_path_2 = {"MainTest2"}
    local parent_path_3 = {"MainTest2","MainTest22"}
    return {{parent_path_1,self._main_menu_test1},
            {parent_path_2,self._main_menu_test2},
            {parent_path_3,self._main_menu_test3}}
end

function TestGuiBase:_main_menu_test1()
    if widget.MenuItem("t1","CTRL+C") then
        print("menu t1 click")
    end
    cursor.Separator()
    if widget.MenuItem("wantcapturemouse","graytext") then
        print("menu t2 click")
    end
    -- cursor.Separator()

end
function TestGuiBase:_main_menu_test2()
    if widget.BeginMenu("t2-1") then
        if widget.MenuItem("t2-11") then
            print("menu t2-1 click")
        end
        widget.EndMenu()
    end
end
function TestGuiBase:_main_menu_test3()
    if widget.MenuItem("t2-2") then
        print("menu 2-2 click")
    end
end
--main menu

return TestGuiBase
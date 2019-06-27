local imgui   = import_package "ant.imgui".imgui
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local gui_mgr = import_package "ant.imgui".gui_mgr

local GuiBase = import_package "ant.imgui".gui_base
local GuiEditorMenu = GuiBase.derive("GuiEditorMenu")

GuiEditorMenu.GuiName = "GuiEditorMenu"

function GuiEditorMenu:_init()
    GuiBase._init(self)
    self.on_gui = false
end


--main menu
function GuiEditorMenu:get_mainmenu()
    local parent_path = {"Editor"}
    return {{parent_path,self._editor_menu}}
end

function GuiEditorMenu:_editor_menu()
    if widget.MenuItem("Save Layout") then
        gui_mgr.save_ini()
    end
end

return GuiEditorMenu
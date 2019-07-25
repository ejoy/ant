local imgui   = import_package "ant.imgui".imgui
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum

local GuiBase = import_package "ant.imgui".gui_base
local GuiSceneMenu = GuiBase.derive("GuiSceneMenu")

GuiSceneMenu.GuiName = "GuiSceneMenu"
function GuiSceneMenu:_get_editbox()
    if self.editbox == nil then
        local editbox = {}
        editbox.text = "test/samples/features/package.lua"
        self.editbox = editbox
    end
    return self.editbox
end
--main menu
function GuiSceneMenu:get_mainmenu()
    local parent_path = {"TestScene"}
    return {{parent_path,self._scene_menu}}
end

function  GuiSceneMenu:_scene_menu()
    
    local box = self:_get_editbox()
    if  widget.Button("OpenScene") then
        local scene_control = require "scene_control"
        log.info_a(box)
        scene_control.test_new_world(box.text)
    end
    cursor.SameLine()
    widget.InputText("", box)

end

return GuiSceneMenu
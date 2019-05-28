local imgui         = require "imgui_wrap"
local widget        = imgui.widget
local flags         = imgui.flags
local windows       = imgui.windows
local util          = imgui.util
local cursor        = imgui.cursor
local GuiCanvas     = require "gui_canvas"
local GuiScene      = class("GuiScene",GuiCanvas)
local scene         = import_package "ant.scene".util
local ru            = import_package "ant.render".util

GuiScene.GuiName = "GuiScene"

function GuiScene:_init()
    GuiCanvas._init(self)
end

function GuiScene:get_mainmenu()
    return {
        {{"Scene"},self._scene_main_menu},
    }
end

function GuiScene:_scene_main_menu()
    if widget.MenuItem("New World","test only") then
        local scene_control = require "scene_control"
        scene_control.test_new_world()
    end
end

return GuiScene
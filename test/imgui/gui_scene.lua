local imgui         = import_package "ant.imgui".imgui
local widget        = imgui.widget
local flags         = imgui.flags
local windows       = imgui.windows
local util          = imgui.util
local cursor        = imgui.cursor
local GuiCanvas     = import_package "ant.imgui".editor.gui_canvas
local scene         = import_package "ant.scene".util
local ru            = import_package "ant.render".util

local GuiScene = GuiCanvas.derive("GuiScene")
GuiScene.GuiName = "GuiScene"

function GuiScene:_init()
    GuiCanvas._init(self)
end

function GuiScene:_get_editpath()
    if self.editpath == nil then
        local editpath = {}
        editpath.text = "test/samples/unity_viking/package.lua"
        self.editpath = editpath
    end
    return self.editpath
end

function GuiScene:_get_editfps()
    if self.editfps == nil then
        self.editfps = {
            30,
            step = 1,
        }
    end
    return self.editfps
end

--main menu
function GuiScene:get_mainmenu()
    local parent_path = {"TestScene"}
    return {{parent_path,self._scene_menu},}
end



function  GuiScene:_scene_menu()
    local box = self:_get_editpath()
    if  widget.Button("OpenScene") then
        local scene_control = require "scene_control"
        print_a(box)
        scene_control.test_new_world(box.text)
    end
	cursor.SameLine()
	widget.InputText("", box)
    cursor.Separator()
    local fps = self:_get_editfps()
    if widget.InputInt("FPS",fps) then
        if fps[1]> 0 then
            self:set_fps(fps[1])
        end
    end
end


return GuiScene
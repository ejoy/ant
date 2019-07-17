local imguipkg      = import_package "ant.imgui"
local dbgutil       = imguipkg.dbgutil
local imgui         = imguipkg.imgui
local widget        = imgui.widget
local flags         = imgui.flags
local windows       = imgui.windows
local util          = imgui.util
local cursor        = imgui.cursor
local GuiCanvas     = imguipkg.editor.gui_canvas
local gui_util     = imguipkg.editor.gui_util
local scene         = import_package "ant.scene".util
local ru            = import_package "ant.render".util
local scene_control = require "scene_control"

local GuiScene = GuiCanvas.derive("GuiScene")
GuiScene.GuiName = "GuiScene"

function GuiScene:_init()
    GuiCanvas._init(self)
    self.message_shown = true
end

function GuiScene:_get_editpath()
    if self.editpath == nil then
        local editpath = {}
        editpath.text = "test/samples/features/package.lua"
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
    local parent_path = {"Scene"}
    return {{parent_path,self._scene_menu},}
end

function GuiScene:on_gui(delta)
    if (not self.world) and (not self.message_shown) then
        local box = self:_get_editpath()
        local message_cb = function(result)
            if result == 1 then
                scene_control.test_new_world(box.text)
            end
        end
        local arg = {
            msg = string.format("Open default scene:%s",box.text),
            close_cb = message_cb,
        }
        gui_util.message(arg)
        self.message_shown = true
    end
    GuiCanvas.on_gui(self,delta)
end

function  GuiScene:_scene_menu()
    local box = self:_get_editpath()
    if  widget.Button("OpenScene") then
        log.info_a(box)
        dbgutil.try(function () scene_control.test_new_world(box.text) end)
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
    widget.Text(string.format("real frame time:%f/(%.2f)",self.cur_frame_time,1/self.cur_frame_time))
end


return GuiScene
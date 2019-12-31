local imguipkg      = import_package "ant.imgui"
local dbgutil       = import_package "ant.editor".debugutil
local imgui         = imguipkg.imgui
local widget        = imgui.widget
local flags         = imgui.flags
local windows       = imgui.windows
local util          = imgui.util
local cursor        = imgui.cursor
local scene_data_accessor  = imguipkg.editor.scene.scene_data_accessor
local Event         = imguipkg.hub_event
local GuiCanvas     = imguipkg.editor.gui_canvas
local gui_util      = imguipkg.editor.gui_util
local scene         = import_package "ant.scene".util
local ru            = import_package "ant.render".util
local scene_control = require "scene_control"
local hub           = import_package "ant.editor".hub 

local GuiScene = GuiCanvas.derive("GuiScene")
GuiScene.GuiName = "GuiScene"

local MAX_RECENT_PATH = 32

function GuiScene:_init()
    GuiCanvas._init(self)
    self.message_shown = false
    self.recent_scenes = {}
    hub.subscribe(Event.OpenScene,self.on_request_open_scene_file,self)
end

function GuiScene:on_request_open_scene_file(path)
    log("on_request_open_scene_file",path)
    scene_data_accessor.start_scene(path)
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
    return {
        {parent_path,self._scene_menu},
    }
end

function GuiScene:on_gui(delta)
    -- if (not self.world) and (not self.message_shown) then
    --     local box = self:_get_editpath()
    --     local message_cb = function(result)
    --         if result == 1 then
    --             self:_open_scene(tostring(box.text))
    --         end
    --     end
    --     local arg = {
    --         msg = string.format("Open default scene:%s",box.text),
    --         close_cb = message_cb,
    --     }
    --     gui_util.message(arg)
    --     self.message_shown = true
    -- end
    GuiCanvas.on_gui(self,delta)
end

function GuiScene:_open_scene(path)
    local status = dbgutil.try(function () scene_control.run_test_package(path) end)
    if status then
        self:save_path_to_recent(path)
    end
end

function  GuiScene:_scene_menu(delta)
    local box = self:_get_editpath()
    if  widget.Button("OpenScene") then
        log.info_a(box)
        local path = tostring(box.text)
        self:_open_scene(path)
    end
	cursor.SameLine()
	widget.InputText("", box)
    self:_recent_scene_menu()
    cursor.Separator()
    local fps = self:_get_editfps()
    if widget.InputInt("FPS",fps) then
        if fps[1]> 0 then
            self:set_fps(fps[1])
        end
    end
    widget.Text(string.format("Frametime(editor):%.2fms FPS:(%.2f)",self.cur_frame_time*1000,1/self.cur_frame_time))
    if self.scene_cost then
        widget.Text(string.format("Frametime(raw):%.2fms FPS:(%.2f)",self.scene_cost*1000,1/self.scene_cost))
    end
end

function GuiScene:_recent_scene_menu()
    if widget.BeginMenu("Recent Scenes") then
        local recent_scenes = self.recent_scenes
        if #recent_scenes == 0 then
            widget.Text("[Empty]")
        else
            local size = #recent_scenes
            for i = size,1,-1 do
                cursor.SetNextItemWidth(40)
                widget.Text(tostring(size-i+1))
                cursor.SameLine()
                local p = recent_scenes[i]
                if widget.Selectable(p,false) then
                    self:_open_scene(p)
                end
            end
        end
        widget.EndMenu()
    end
end

function GuiScene:save_path_to_recent(path)
    local recent_scenes = self.recent_scenes
    --check can find
    local found = false
    for i,p in ipairs(recent_scenes) do
        if  p == path then
            found = i
            break
        end
    end
    if found then
        if found ~= #recent_scenes then
            table.remove(recent_scenes,found)
            table.insert(recent_scenes,path)
            self:mark_setting_dirty()
        end
    else
        if #self.recent_scenes >= MAX_RECENT_PATH then
            table.remove(self.recent_scenes,1)
        end
        table.insert(recent_scenes,path)
        self:mark_setting_dirty()
    end
end

--override if needed
--return tbl
function GuiScene:save_setting_to_memory(clear_dirty_flag)
    local setting = GuiCanvas.save_setting_to_memory(self,clear_dirty_flag)
    setting.recent_scenes = self.recent_scenes
    return setting
end

--override if needed
function GuiScene:load_setting_from_memory(setting_tbl)
    self.recent_scenes = setting_tbl.recent_scenes or {}
    local recent_size = #self.recent_scenes
    if recent_size > 0 then
        local box = self:_get_editpath()
        box.text = self.recent_scenes[recent_size]
    end
    GuiCanvas.load_setting_from_memory(self,setting_tbl)
end

return GuiScene
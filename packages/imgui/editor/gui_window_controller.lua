local dbgutil       = import_package "ant.editor".debugutil
local GuiBase       = require "gui_base"
local scene         = import_package "ant.scene".util
local ru            = import_package "ant.render".util
local bgfx = require "bgfx"
local fs = require "filesystem"
local pm = require "antpm"
local gui_mgr       = require "gui_mgr"
local hub           = import_package "ant.editor".hub
local Event         = require "hub_event"


local GuiWindowController = GuiBase.derive("GuiWindowController")
GuiWindowController.GuiName = "GuiWindowController"


local GuiProjectList = require "editor.projects.gui_project_list"

local function create_window_title(editor_name,project_name)
    return string.format("%s - %s",editor_name,project_name)
end

function GuiWindowController:_init()
    self.dont_show_in_mainmenu = true
    GuiBase._init(self)
    self:_init_subcribe()
    self.create_title_func = create_window_title
    self:refresh_window_status()
end



function GuiWindowController:_init_subcribe()
    hub.subscribe(Event.OpenProject,self._on_open_project,self)
    hub.subscribe(Event.CloseProject,self._on_close_project,self)
end

function GuiWindowController:refresh_window_status()
    local editor_name = gui_mgr.EditorName
    local project_list = GuiProjectList:get_ins()
    local project_name = project_list and project_list:get_cur_project_name()
    local title = self.create_title_func(editor_name,project_name)
    gui_mgr.set_window_title(title)
end

function GuiWindowController:_on_open_project()
    self:refresh_window_status()
end


function GuiWindowController:_on_close_project()
    self:refresh_window_status()
end


function GuiWindowController:on_gui(delta)
    
end

return GuiWindowController
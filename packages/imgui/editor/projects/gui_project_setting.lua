local imgui             = require "imgui_wrap"
local widget            = imgui.widget
local flags             = imgui.flags
local windows           = imgui.windows
local util              = imgui.util
local cursor            = imgui.cursor
local enum              = imgui.enum
local IO                = imgui.IO

local pm                = require "antpm"
local gui_input         = require "gui_input"
local gui_mgr           = require "gui_mgr"
local gui_util          = require "editor.gui_util"
local fs                = require "filesystem"
local lfs               = require "filesystem.local"

local project_data_accessor    = require "editor.projects.project_data_accessor"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local GuiBase           = require "gui_base"
local GuiProjectSetting    = GuiBase.derive("GuiProjectSetting")
GuiProjectSetting.GuiName  = "GuiProjectSetting"
-- local SelectableHeight = cursor.GetTextLineHeight()+cursor.GetTextLineHeightWithSpacing()

function GuiProjectSetting:_init()
    GuiBase._init(self)
    self.win_flags = flags.Window { "MenuBar" }
    self.title_id = string.format("ProjectSetting###%s",self.GuiName)
    -- self.default_size = {800,700}
    self:_init_subcribe()
end

function GuiProjectSetting:_init_subcribe()
    
end

return GuiProjectSetting
local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local class     = require "common.class"

local GuiBase = require "gui_base"
GuiPackages = class("GuiPackages",GuiBase)

function GuiPackages:_init()
    self._registereds = nil
    self.cur_package_name = nil
    
end

function GuiPackages:_load_package()
    
end

function GuiPackages:on_update()
    --package combobox
    --dir tree
    --file list
end

return GuiPackages
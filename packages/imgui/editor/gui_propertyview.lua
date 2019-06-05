local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local IO = imgui.IO

local GuiBase = require "gui_base"
local GuiPropertyView = GuiBase.derive("GuiPropertyView")
GuiPropertyView.GuiName = "GuiPropertyView"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

function GuiPropertyView:_init()
    GuiBase._init(self)
    self:_init_subcribe()
end

function GuiPropertyView:_init_subcribe()
    hub.subscribe(Event.HierarchyChange,self._on_refresh_hierarchy,self)
end

function GuiPropertyView:_on_refresh_hierarchy(tbl)
    print_a("_on_refresh_hierarchy",tbl)
end

function GuiPropertyView:on_update()
    widget.Text("I'm here!!!!!!")
end

return GuiPropertyView
local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local IO = imgui.IO

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local widget_entity = require "widget.gui_entity_widget"

local GuiBase = require "gui_base"
local GuiPropertyView = GuiBase.derive("GuiPropertyView")
GuiPropertyView.GuiName = "GuiPropertyView"

function GuiPropertyView:_init()
    GuiBase._init(self)
    self.default_size = {250,600}
    self.title_id = string.format("Property###%s",self.GuiName)
    ---
    self:_init_subcribe()
end

-------hub begin
function GuiPropertyView:_init_subcribe()
    hub.subscribe(Event.EntityChange,self._on_refresh_entity,self)
    hub.subscribe(Event.ResponseWorldInfo,
                self.on_response_world_info,
                self)
end

function GuiPropertyView:request_world_info()
    hub.publish(Event.RequestWorldInfo)
end
-------hub end

function GuiPropertyView:on_response_world_info(tbl)
    print_a(tbl)
    self.world_info = tbl
end

function GuiPropertyView:_on_refresh_entity(tbl)
    print_a(tbl)
    self.entity_tbl = tbl
end

function GuiPropertyView:on_update()
    widget.Text("GuiPropertyView")
    if self.entity_tbl then
        if not self.world_info then
            self:request_world_info()
            return
        end
        local eid,entity = next(self.entity_tbl)
        if eid then
            widget_entity.update(eid,entity,self.world_info.schemas)
        end
    end
end

return GuiPropertyView
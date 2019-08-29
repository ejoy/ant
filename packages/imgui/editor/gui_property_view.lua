local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local IO = imgui.IO
local gui_util = require "editor.gui_util"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local EntityWidget = require "widget.gui_entity_widget"

local GuiBase = require "gui_base"
local GuiPropertyView = GuiBase.derive("GuiPropertyView")
GuiPropertyView.GuiName = "GuiPropertyView"

function GuiPropertyView:_init()
    GuiBase._init(self)
    self.win_flags = flags.Window { "MenuBar" }
    self.default_size = {250,600}
    self.title_id = string.format("Property###%s",self.GuiName)
    self.widget_entity = EntityWidget.new()
    self.debug_mode = false
    self.widget_entity:set_debug_mode(self.debug_mode)
    self.widget_entity:set_change_cb(self.on_component_value_change,self)
    self._dirty_flag = false
    self.base_component_cfg = {offset_2 = 200}
    ---
    
    self:_init_subcribe()
end

function GuiPropertyView:on_component_value_change(eid,com_id,name,value)
    hub.publish(Event.ModifyComponent,eid,com_id,name,value)
end

-------hub begin
function GuiPropertyView:_init_subcribe()
    hub.subscribe(Event.EntityInfo,self._on_refresh_entity,self)
    -- hub.subscribe(Event.ResponseWorldInfo,
    --             self.on_response_world_info,
    --             self)
end

function GuiPropertyView:request_world_info()
    hub.publish(Event.RequestWorldInfo)
end
-------hub end

function GuiPropertyView:on_response_world_info(tbl)
    log.info_a(tbl)
    self.world_info = tbl
end

function GuiPropertyView:_on_refresh_entity(tbl)
    if tbl.type ~= "auto" then 
        log.info_a(tbl)
    end
    if self.widget_entity and self.widget_entity.is_editing then
        self.temp_entity_tbl = tbl.entities
    else
        self.temp_entity_tbl = nil
        self.entity_tbl = tbl.entities
    end
end

function GuiPropertyView:reset_com_setting()
    if self.schemas then
        self.com_setting = gui_util.read_component_setting(self.schemas)
        self.widget_entity:set_com_setting(self.com_setting)
        return true
    else
        return false
    end
end

function GuiPropertyView:on_update()
    -- widget.Text("GuiPropertyView")
    if widget.BeginMenuBar() then
        if widget.MenuItem("Refresh Component Setting") then
            self:reset_com_setting()
        end
        local change
        change,self.debug_mode = widget.Checkbox("Debug",self.debug_mode)
        if change then
            self.widget_entity:set_debug_mode(self.debug_mode)
        end
        widget.EndMenuBar()
    end
    if self.entity_tbl then
        -- if not self.world_info then
        --     self:request_world_info()
        --     return
        -- end
        if not self.schemas then
            local util = require "editor.gui_util"
            local schema_map = util.get_all_schema()
            self.schemas = schema_map
            self.widget_entity:set_schema(self.schemas)
        end
        if (not self.com_setting) then
            self:reset_com_setting()
        end

        local eid,entity = next(self.entity_tbl)
        if eid then
            local is_editing = self.widget_entity.is_editing
            self.widget_entity:update(eid,entity,self.base_component_cfg)
            if (not is_editing) and (self.widget_entity.is_editing) then
                if self.temp_entity_tbl then
                    self.entity_tbl = self.temp_entity_tbl
                    self.temp_entity_tbl = nil
                end
            end
        end
    else
        widget.Text("Not Entity")
    end
end

----------------custom_setting----------------

--override if needed
--return tbl
function GuiPropertyView:save_setting_to_memory(clear_dirty_flag)
    if clear_dirty_flag then
        self._dirty_flag = false
    end
    return {
    }
end

--override if needed
function GuiPropertyView:load_setting_from_memory(seting_tbl)
end

--override if needed
function GuiPropertyView:is_setting_dirty()
    return self._dirty_flag
end

----------------custom_setting----------------

return GuiPropertyView
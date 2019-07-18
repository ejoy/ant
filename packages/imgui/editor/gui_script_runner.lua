local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local gui_input = require "gui_input"
local bgfx      = require "bgfx"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"


local GuiBase = require "gui_base"
local GuiScriptRunner = GuiBase.derive("GuiScriptRunner")


GuiScriptRunner.GuiName = "GuiScriptRunner"

function GuiScriptRunner:_init()
    GuiBase._init(self)
    self.title_id = "ScriptRunner"
    self.win_flags = flags.Window { }
    self._is_opened = true
    self._setting_dirty = false
    self.input_cache = {
        text = "",
        dirty = false,
        flags = flags.InputText{ "Multiline","CallbackCompletion"},
        width = -1,
        height = -1,
    }
    self.input_cache.tab = function(eb)
        self._setting_dirty = self._setting_dirty or self.input_cache.dirty
        self.input_cache.dirty = false
    end
end

function GuiScriptRunner:on_update(delta)
    if widget.Button("Run in ecs") then
        hub.publish(Event.RunScript, tostring(self.input_cache.text))
    end
    if widget.InputText("##detail",self.input_cache) then
        self.input_cache.dirty = true
    end
    if util.IsItemActive() then
        self.input_cache.foucs = true
    elseif self.input_cache.foucs then
        self.input_cache.foucs = false
        self.input_cache.tab()
    end
end

function GuiScriptRunner:is_setting_dirty()
    return self._setting_dirty
end

function GuiScriptRunner:load_setting_from_memory(setting)
    if setting.script ~= nil then
        self.input_cache.text = setting.script
        self.input_cache.dirty = false
    end
end

function GuiScriptRunner:save_setting_to_memory(clear_dirty_flag)
    if clear_dirty_flag then
        self._setting_dirty = false
    end
    self.input_cache.dirty = false
    return {
        script = tostring(self.input_cache.text)
    }
end



return GuiScriptRunner
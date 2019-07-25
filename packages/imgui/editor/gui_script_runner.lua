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
local gui_util = require "editor.gui_util"

local GuiBase = require "gui_base"
local GuiScriptRunner = GuiBase.derive("GuiScriptRunner")

local DefaultPath = "script_runner.user.lua"

GuiScriptRunner.GuiName = "GuiScriptRunner"

function GuiScriptRunner:_init()
GuiBase._init(self)
    self.title_id = "ScriptRunner"
    self.win_flags = flags.Window { }
    self._is_opened = true
    self._setting_dirty = false
    self.input_cache = {
        text = "",
        flags = flags.InputText{ "Multiline","CallbackCompletion"},
        width = -1,
        height = -1,
        id = 0,
    }
    self.input_cache.tab = function(eb)
        self._setting_dirty = self._setting_dirty or self.file_modified_inside
    end
    self.file_watch = nil
    self.current_file_path = DefaultPath
    self.file_modified_inside = false
    self.file_modified_outside = false
    local f,real_path = gui_util.open_current_pkg_path(self.current_file_path,"a")
    self.current_file_real_path = real_path
    f:close()
    self:reset_file()
end

-----sync script file -------------------
function GuiScriptRunner:create_file_watch()
    local cb = function(type)
        log.trace("script watch event:",type)
        if type == "delete" then
            local f = gui_util.open_current_pkg_path(self.current_file_path,"a")
            f:close()
        end
        self.file_modified_outside = true
    end
    self.file_watch = gui_util.watch_current_package_file(self.current_file_path,cb)
end

function GuiScriptRunner:refresh_file()
    if self.file_modified_outside then
        self:reset_file()
    end

end

function GuiScriptRunner:save_to_file()
    local f = gui_util.open_current_pkg_path(self.current_file_path,"w")
    f:write(tostring(self.input_cache.text))
    f:close()
    self.file_modified_inside = false
    self._setting_dirty = true
end

function GuiScriptRunner:reset_file()
    local f = gui_util.open_current_pkg_path(self.current_file_path,"r")
    local script_content = f:read("*all")
    f:close()
    self.input_cache.text  = script_content
    self.input_cache.id = self.input_cache.id + 1
    self.file_modified_outside = false
    self.file_modified_inside = false
    self._setting_dirty = true
end
-----sync script file -------------------

function GuiScriptRunner:on_update(delta)
    if self.file_watch == nil and self.current_file_path then
        self:create_file_watch()
    end
    self.file_watch()
    self:refresh_file()
    if widget.Button("Run In Ecs") then
        self.input_cache.tab()
        hub.publish(Event.RunScript, tostring(self.input_cache.text))
    end
    cursor.SameLine()
    if widget.Button("Sync") then
        self:reset_file()
    end
    widget.Text(string.format("File:%s",self.current_file_real_path))
    if self.file_modified_inside then
        cursor.SameLine()
        if widget.Button("Save") then
            self:save_to_file()
        end
        cursor.SameLine()
        if widget.Button("Reset") then
            self:reset_file()
        end
    end
    if widget.InputText("##detail"..self.input_cache.id,self.input_cache) then
        self.file_modified_inside = true
    end
    if util.IsItemActive() then
        self.input_cache.foucs = true
    elseif self.input_cache.foucs then
        self.input_cache.foucs = false
        self.input_cache.tab()
    end
end

----setting----------------------
function GuiScriptRunner:is_setting_dirty()
    return self._setting_dirty
end

function GuiScriptRunner:load_setting_from_memory(setting)
        self.file_modified_inside = setting.file_modified_inside
        if setting.file_modified_inside then
            self.input_cache.text = setting.script
        end
end

function GuiScriptRunner:save_setting_to_memory(clear_dirty_flag)
    if clear_dirty_flag then
        self._setting_dirty = false
    end
    self.input_cache.dirty = false
    return {
        script = self.file_modified_inside and tostring(self.input_cache.text),
        file_modified_inside = self.file_modified_inside
    }
end
----setting----------------------


return GuiScriptRunner
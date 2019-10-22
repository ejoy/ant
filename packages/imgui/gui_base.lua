local class     = require "common.class"
local GuiBase   = class("GuiBase")
local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local dbgutil = import_package "ant.editor".debugutil


GuiBase.GuiName = "GuiBase"

function GuiBase:_init()
    --use by imgui,keep ID the same value
    self.title_id = string.format("this_is_title###%s",self.GuiName)
    -- self.win_flags = flags.Window { "MenuBar" }
    self._is_opened = true
    -- self.default_size = {200,100}
    self._last_frame_opened = false
    self._err_count = 0
    self.dont_show_in_mainmenu = false
end

function GuiBase:on_open_click()
    self._is_opened = true
end

function GuiBase:is_opened()
    return self._is_opened
end

function GuiBase:before_open()
    self.before_open = false
end

--override if needed
function GuiBase:before_update()
    --call windows.SetNextWindowXXX here
    self.before_update = false
end

--override if needed
function GuiBase:after_update()
    --call windows.SetNextWindowXXX here
    self.after_update = false
end

function GuiBase:after_close()
    self.after_close = false
end


function GuiBase:on_close_click()
    self._is_opened = false
end

--return ret,status
function GuiBase:try(fun,...)
    return dbgutil.try(fun,...)
end

--call by gui_mgr each frame
function GuiBase:on_gui(delta)
    if self._is_opened then
        if not self._last_frame_opened then
            self._last_frame_opened = true
            if self.before_open then
                self:before_open()
            end 
        end
        local default_size = self.default_size
        if self.default_size then
            windows.SetNextWindowSize(default_size[1],default_size[2],"FirstUseEver")
        end
        if self.before_update then self:before_update() end
        local fold, opening = windows.Begin(self.title_id, self.win_flags or nil)
        if self._err_count < 60 and  fold then
            local ok = self:try(self.on_update,self,delta)
            if not ok then
                self._err_count = self._err_count + 1
            else
                self._err_count = 0
            end
            if not opening then
                self:on_close_click()
            end
        end
        windows.End()
        if self.after_update then self:after_update() end
    else
        if self._last_frame_opened then
            self._last_frame_opened = false
            if self.after_close then
                self:after_close()
            end 
        end
    end
end


function GuiBase:on_update(delta)
    
end

--override if needed
function GuiBase:get_mainmenu()
    self.get_mainmenu = false
end

function GuiBase.get_ins(MyClass)
    local gui_mgr = require "gui_mgr"
    local ins = gui_mgr.get(MyClass.GuiName)
    return ins
end


----------------custom_setting----------------

--override if needed
--return tbl
function GuiBase:save_setting_to_memory(clear_dirty_flag)
    
end

--override if needed
function GuiBase:load_setting_from_memory(seting_tbl)
    self.load_setting_from_memory = false
end

--override if needed
function GuiBase:is_setting_dirty()
    return false
end

----------------custom_setting----------------

return GuiBase
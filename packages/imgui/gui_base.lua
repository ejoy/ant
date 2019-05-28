local GuiBase   = class("GuiBase")
local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util


GuiBase.GuiName = "GuiBase"

function GuiBase:_init()
    --use by imgui,keep ID the same value
    self.title_id = "this_is_title###this_is_id"
    -- self.win_flags = flags.Window { "MenuBar" }
    self._is_opened = true
end

function GuiBase:on_open_click()
    self._is_opened = true
end

function GuiBase:is_opened()
    return self._is_opened
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

function GuiBase:on_close_click()
    self._is_opened = false
end

--call by gui_mgr each frame
function GuiBase:on_gui(delta)
    if self._is_opened then
        if self.before_update then self:before_update() end
        local fold, opening = windows.Begin(self.title_id, self.win_flags or nil)
        if fold then
            self:on_update(delta)
            if not opening then
                self:on_close_click()
            end
        end
        windows.End()
        if self.after_update then self:after_update() end
    end
end


function GuiBase:on_update(delta)
    
end

--override if needed
function GuiBase:get_mainmenu()
    self.get_mainmenu = false
end

return GuiBase
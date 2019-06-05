local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local gui_input = require "gui_input"

local GuiBase = require "gui_base"
local GuiSysInfo = GuiBase.derive("GuiSysInfo")


GuiSysInfo.GuiName = "GuiSysInfo"
local DISTANCE = 10
function GuiSysInfo:_init()
    GuiBase._init(self)
    self.title = "GuiSysInfo"
    self.win_flags1 = flags.Window { "NoMove",
        "NoTitleBar","NoResize","AlwaysAutoResize",
        "NoSavedSettings","NoFocusOnAppearing","NoNav" }
    self.win_flags2 = flags.Window { 
        "NoTitleBar","NoResize","AlwaysAutoResize",
        "NoSavedSettings","NoFocusOnAppearing","NoNav" }
    self._is_opened = true
    -----
    self.corner = 2
    self.winpos = {0,0}
    self.povit = {0,0}

end

function GuiSysInfo:before_update()
    local screen_size = gui_input.screen_size
    local corner = self.corner
    local winpos = self.winpos
    local povit = self.povit
    if corner ~= -1 then
        if corner & 1 > 0 then
            winpos[1] = screen_size[1] - DISTANCE
            povit[1] = 1.0;
        else
            winpos[1] = DISTANCE
            povit[1] = 0.0;
        end
        if corner & 2 > 0 then
            winpos[2] = screen_size[2] - DISTANCE
            povit[2] = 1.0;
        else
            winpos[2] = DISTANCE
            povit[2] = 0.0;
        end
        self.win_flags = self.win_flags1 --no move
    else
        self.win_flags = self.win_flags2 --can move
    end
    windows.SetNextWindowBgAlpha(0.35)
    windows.SetNextWindowPos( winpos[1],winpos[2],nil,povit[1],povit[2] )
end

local btns = {"Custom","Top-left","Top-right","Bottom-left","Bottom-right"}

function GuiSysInfo:on_update()
    local corner = self.corner
    local framerate = imgui.IO.Framerate
    widget.Text( string.format("fps:%f",framerate) )
    widget.Text( string.format("frame time:%f",1/framerate) )
    if windows.BeginPopupContextWindow() then
        for i = -1,3 do
            local btn_str = btns[i+2]
            if widget.MenuItem(btn_str,nil,nil,corner ~= i) then
                corner = i
            end
        end
        self.corner = corner
        if widget.MenuItem("close") then
            self:on_close_click()
        end
        windows.EndPopup()
    end
end

return GuiSysInfo
local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local class     = require "common.class"
local GuiBase = require "gui_base"
local GuiLogView = GuiBase.derive("GuiLogView")

GuiLogView.GuiName = "GuiLogView"

function GuiLogView:_init()
    GuiBase._init(self)
    self.title = "GuiLogView"
    self.win_flags = flags.Window { "MenuBar" }
    self._is_opened = true
    -----

end
local cbval = false
function GuiLogView:on_update()
    widget.Text("Testasdssssssssssssssssssssssssssssssss\nHere!")
    if widget.BeginMenuBar() then
        local change,val = widget.Checkbox("Open",cbval)
        if change then
            cbval = val
        end
        widget.EndMenuBar()
    end
    local msg_item = {type="A", lv = 0, msg = "asdasdasdasdasdasd\
    asdasddddddddddddddd\nddddddddddddddddd"}
    windows.BeginChild("content",0,200,0)
    for i = 1,10 do
        
    end

    windows.EndChild()


end

function GuiLogView:on_msg()

end

return GuiLogView
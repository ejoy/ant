local imgui = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local class     = require "common.class"
local ComboBox = class("ImguiList")

function ComboBox:_init(title)
    self.list_source = {"Empty"}
    self.title = title or "List"
    self.ext_tbl = {}
    self.title_flags = flags.Combo {}
    self.item_flag = flags.Selectable {}
    self.ext_tbl = {}
end

--title_flags : flags.Combo
--item_flags : flags.Selectable
function ComboBox:set_flags( title_flags,item_flags )
    self.title_flags = title_flags or self.title_flags
    self.item_flags = item_flags or self.item_flags
end

function ComboBox:set_data(datalist,select_index)
    self.current = select_index
    self.datalist = datalist
    local ext_tbl = self.ext_tbl
    ext_tbl[1] = datalist[self.current]
    ext_tbl["flags"] = self.title_flags
    ext_tbl["item_flags"] = self.item_flags
end

function ComboBox:update()
    local ext_tbl = self.ext_tbl
    local change = false 
    if widget.BeginCombo(self.title,ext_tbl) then
        local datalist = self.datalist
        for i,label in ipairs(datalist) do
            if widget.Selectable(label,ext_tbl,nil) then
                self.current = i
                change = true
            end
        end
        widget.EndCombo()
        if change and self._change_cb then
            self._change_cb(self.current)
        end
    end
end

function ComboBox:set_selected_change_cb(cb,target)
    if target then
        self._change_cb = function( ... )
            cb(target,...)
        end
    else
        self._change_cb = cb
    end
end

function ComboBox:get_selected_index()
    return self.current
end

function ComboBox:set_selected_index(value)
    self.current = value
    self.ext_tbl[1] = self.datalist[self.current]
end

return ComboBox
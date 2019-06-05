local imgui = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor


local class = require "common.class"

local List = class("ImguiList")

function List:_init(title)
    self.list_source = {"Empty"}
    self.title = title or "List"
end

function List:set_data(datalist,select_index,height,title)
    local source = datalist
    source.current = select_index or source.current
    source.height = height or source.height
    self.list_source = source
    self.title = title or self.title
end

function List:update()
    local change = widget.ListBox(self.title,
        self.list_source)
    if change and self._change_cb then
        self._change_cb(self.list_source.current)
    end
    return change
end

function List:set_selected_change_cb(cb,target)
    if target then
        self._change_cb = function( ... )
            cb(target,...)
        end
    else
        self._change_cb = cb
    end
end

function List:get_selected_index()
    return self.list_source.current
end

function List:set_selected_index(value)
    self.list_source.current = value
end

return List
local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local IO = imgui.IO
local gui_input = require "gui_input"
local gui_util = require "editor.gui_util"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local GuiBase = require "gui_base"
local GuiMsgWatchView = GuiBase.derive("GuiMsgWatchView")
GuiMsgWatchView.GuiName = "GuiMsgWatchView"

function GuiMsgWatchView:_init()
    GuiBase._init(self)
    self.default_size = {500,550}
    self.title_id = string.format("GameMessageWatch###%s",self.GuiName)
    self:_init_subcribe()
    self.cur_msg_box = {
        {"mouse","LEFT",[0] = true},
        {"mouse","RIGHT",[0] = true},
        {"keyboard",[0] = true},
    }
    self.edit_info = nil--{ msg_index,part_index}
    self.edit_box = {
        text = "",
    }
    self.change = true
end

function GuiMsgWatchView:_init_subcribe()
    -- hub.subscribe(Event.RTE.ResponseWatchMsg,self.on_response_watch_msg,self)
end

function GuiMsgWatchView:on_response_watch_msg(msg_tbl)
    self.cur_msg_box = msg_tbl
    self.edit_info = nil
    self.change = false
end

function GuiMsgWatchView:sync_msg_tbl_to_game(msg_box)
    if msg_box then
        local filter_msg_box = {}
        for i,msg in ipairs(msg_box) do
            local pure_msg = {}
            for j,key in ipairs(msg) do
                pure_msg[j] = key
            end
            filter_msg_box[i] = pure_msg
        end
        hub.publish(Event.ETR.RequestModifyWatchMsg,filter_msg_box)
    end
    self.edit_info = nil
    self.change = false
end

function GuiMsgWatchView:before_open()
    -- hub.publish(Event.ETR.RequestGetWatchMsg)
end

function GuiMsgWatchView:on_update()
    if not self.cur_msg_box then
        return
    end
    self:render_ui()
end

function GuiMsgWatchView:render_ui()
    for i,msg in ipairs(self.cur_msg_box) do
        util.PushID(i)
        local change,enable = widget.Checkbox(string.format("Sub %d",i),msg[0])
        if change then
            msg[0] = enable
            self.change = true
        end
        cursor.Indent()
        for j,part in ipairs(msg) do
            self:_render_part_item(i,j,msg)
            cursor.SameLine()
        end
        if widget.Button("+") then
            table.insert(msg,"key"..(#msg+1))
            self.change = self.change or msg[0]
        end
        cursor.SameLine()
        if widget.Button("del") then
            table.remove(self.cur_msg_box,i)
            self.edit_info = nil
            self.change = self.change or msg[0]
        end
        cursor.Unindent()
        cursor.Separator()
        util.PopID()
    end
    widget.BulletText("")
    cursor.SameLine()
    if widget.Button("Add Subscribe") then
        table.insert(self.cur_msg_box,{[0]=true,[1]="key1"})
        self.change = true
    end
    if self.change and (not self.edit_info) then
        if widget.Button("Confirm Subscribe") then
            self:sync_msg_tbl_to_game(self.cur_msg_box)
        end
    end
end

function GuiMsgWatchView:_render_part_item(i,j,msg)
    if self.edit_info and self.edit_info[1] == i and self.edit_info[2] == j then
        if widget.InputText(string.format("###%d-%d",i,j),self.edit_box) then
        end
        cursor.SameLine()
        if widget.Button("√") then
            local new_v = tostring(self.edit_box.text)
            if msg[j] ~= new_v then
                msg[j] = new_v
                self.change = self.change or msg[0]
                if new_v == "" then
                    table.remove(msg,j)
                end
            end
            self.edit_info = nil
        end
        cursor.SameLine()
        if widget.Button("x") then
            self.edit_info = nil
        end
    else
        local my_text = msg[j]
        widget.Text(my_text)
        if util.IsItemClicked() then
            self.edit_info = {i,j}
            self.edit_box.text = my_text
        end
    end
end

function GuiMsgWatchView:after_close()
    hub.publish(Event.ETR.RequestModifyWatchMsg,{})
    self.change = true
end

return GuiMsgWatchView
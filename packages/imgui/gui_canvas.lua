local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local IO      = imgui.IO
local class     = require "common.class"

local GuiBase = require "gui_base"
local gui_input = require "gui_input"
local GuiCanvas = class("GuiCanvas",GuiBase)
local scene         = import_package "ant.scene".util
local ru = import_package "ant.render".util
local map_imgui   = import_package "ant.editor".map_imgui

GuiCanvas.GuiName = "GuiCanvas"

function GuiCanvas:_init()
    GuiBase._init(self)
    self.win_flags = flags.Window { "NoCollapse","NoClosed"}
    self.rect = {x=0,y=0,w=600,h=400}
    self.title_id = "Scene###Scene"
end

function GuiCanvas:bind_world( world,msgqueue )
    self.world = world
    ru.modify_view_rect(self.world,self.rect)
    map_imgui(msgqueue,self)
end

function GuiCanvas:on_close_click()
    --dont close now
end

function GuiCanvas:before_update()
    if self.world then
        windows.SetNextWindowBgAlpha(0.0)
    else
        windows.SetNextWindowBgAlpha(1.0)
    end
    windows.SetNextWindowSize(self.rect.w,self.rect.h, "f")
    windows.PushStyleVar(enum.StyleVar.WindowPadding,0,0)
end

local focus_flag = flags.Focused {"ChildWindows"}
function GuiCanvas:on_update()
    local w,h = windows.GetContentRegionAvail()
    local x,y = cursor.GetCursorScreenPos()
    local r = self.rect
    self.size_change = false
    if w~=r.w or h~=r.h or x~=r.x or y ~= r.y then
        self.size_change = w~=r.w or h~=r.h
        self.rect = {x=x,y=y,w=w,h=h}
        if self.world then
            ru.modify_view_rect(self.world,self.rect)
        end
    end
    widget.InvisibleButton("###InvisibleButton",w,h)
    local focus = windows.IsWindowFocused(focus_flag)
    if focus and IO.WantCaptureMouse then
        --todo:split mouse and keyboard
        self:on_dispatch_msg()
    end
end

function GuiCanvas:on_dispatch_msg()
    --todo:split mouse and keyboard
    local gui_input = gui_input
    local in_mouse = gui_input.mouse
    local in_key = gui_input.key_state
    local key_down = gui_input.key_down
    local called = gui_input.called
    local rect = self.rect
    local rx,ry = 0,0
    if in_mouse.x then
        rx,ry = in_mouse.x - rect.x,in_mouse.y - rect.y
    end
    if self.button_cb then
        for i = 0,4 do
            if called[i] then
                self.button_cb(self,i,in_mouse[i],rx,ry,in_key,in_mouse)
            end
        end
    end
    if self.motion_cb and called.mouse_move then
        self.motion_cb(self,rx,ry,in_key,in_mouse)
    end
    if self.wheel_cb and called.mouse_wheel then
        self.wheel_cb(self,in_mouse.scroll,rx,ry)
    end
    local keypress_cb = self.keypress_cb
    if keypress_cb and #key_down > 0 then
        for _,record in ipairs(key_down) do
            keypress_cb(self,record[1],record[2],in_key,in_mouse)
        end
    end
    if self.resize_cb and self.size_change then
        self.resize_cb(self,rect.w,rect.h)
    end
end
function GuiCanvas:after_update()
    windows.PopStyleVar()
end


return GuiCanvas
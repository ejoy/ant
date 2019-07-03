local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local IO      = imgui.IO
local hub       = import_package "ant.editor".hub

local GuiBase = require "gui_base"
local gui_input = require "gui_input"
local GuiCanvas = GuiBase.derive("GuiCanvas")
local scene         = import_package "ant.scene".util
local ru = import_package "ant.render".util
local map_imgui   = import_package "ant.editor".map_imgui

local DEFAULT_FPS = 30

GuiCanvas.GuiName = "GuiCanvas"

function try(fun,...)
    if debug.getregistry()["lua-debug"] then
        return fun(...)
    end

    local status,err,ret = xpcall( fun,debug.traceback,... )
    if not status then
        io.stderr:write("Error:%s\n%s", status or "nil", err)
    end
    return ret
end

local function get_time()
    return os.clock()
end

function GuiCanvas:_init()
    GuiBase._init(self)
    self.win_flags = flags.Window { "NoCollapse","NoClosed","NoScrollbar"}
    self.rect = {x=0,y=0,w=600,h=400}
    self.title_id = "Scene###Scene"
    self.vp_dirty = false
    self.time_count = 0
    self.cur_frame_time = 0.0
    self:set_fps(DEFAULT_FPS)
end

function GuiCanvas:set_fps(fps)
    assert(fps>0)
    self.fps = fps
    self.frame_time = 1/fps
end

function GuiCanvas:bind_world( world,world_update,msgqueue )
    self.world = world
    self.world_update = world_update
    local rect = {x=0,y=0,w=self.rect.w,h=self.rect.h}
    map_imgui(msgqueue,self)

    self.next_frame_time = 0
    self.time_count = 0
    self.last_update = nil

end

function GuiCanvas:on_close_click()
    --dont close
end

function GuiCanvas:before_update()
    windows.SetNextWindowSize(self.rect.w,self.rect.h, "f")
    windows.PushStyleVar(enum.StyleVar.WindowPadding,0,0)
end

local focus_flag = flags.Focused {"ChildWindows"}
function GuiCanvas:on_update(delta)
    local w,h = windows.GetContentRegionAvail()
    local x,y = cursor.GetCursorScreenPos()
    local r = self.rect
    if w~=r.w or h~=r.h or x~=r.x or y ~= r.y then
        self.vp_dirty = self.vp_dirty or (w~=r.w) or (h~=r.h)
        if  (w~=r.w) or (h~=r.h) then
            print(">>>>>>",w,r.w,h,r.h)
        end
        self.rect = {x=x,y=y,w=w,h=h}
    end
    if self.world then
        local world_tex =  ru.get_main_view_rendertexture(self.world)
        if world_tex then
            widget.ImageButton(world_tex,w,h,{frame_padding=0,bg_col={0,0,0,1}})
        end
    end
    if IO.WantCaptureMouse then
        --todo:split mouse and keyboard
        self:on_dispatch_msg()
    end
    if self.world_update then
        self:_update_world(delta)
    end
end

function GuiCanvas:_update_world(delta)
    local now = self.time_count + delta
    self.time_count = now
    if now >= self.next_frame_time then
        if self.last_update then
            self.cur_frame_time = now - self.last_update
        end
        self.next_frame_time = now + self.frame_time
        self.last_update = now
        --update world
        try(self.world_update)
    end

end



function GuiCanvas:on_dispatch_msg()
    --todo:split mouse and keyboard``
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
    local focus = windows.IsWindowFocused(focus_flag)
    local hovered = windows.IsWindowHovered(focus_flag)

    if focus and self.button_cb then
        for i = 0,4 do
            if called[i] then
                self.button_cb(self,i,in_mouse[i],rx,ry,in_key,in_mouse)
            end
        end
    end
    if focus and self.motion_cb and called.mouse_move then
        self.motion_cb(self,rx,ry,in_key,in_mouse)
    end
    if hovered and self.wheel_cb and called.mouse_wheel then
        self.wheel_cb(self,in_mouse.scroll,rx,ry)
    end
    local keypress_cb = self.keypress_cb
    if focus and keypress_cb and #key_down > 0 then
        for _,record in ipairs(key_down) do
            keypress_cb(self,record[1],record[2],in_key,in_mouse)
        end
    end
    local mouse_pressed =  gui_input.is_mouse_pressed(0)
    if focus and not mouse_pressed and self.resize_cb and self.vp_dirty then
        self.vp_dirty = false
        self.resize_cb(self,rect.w,rect.h)
    end
end
function GuiCanvas:after_update()
    windows.PopStyleVar()
end


return GuiCanvas
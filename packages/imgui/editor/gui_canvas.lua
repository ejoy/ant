local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local IO      = imgui.IO
local hub       = import_package "ant.editor".hub
local Event = require "hub_event"

local inputmgr = import_package "ant.inputmgr"

local GuiBase = require "gui_base"
local gui_input = require "gui_input"
local GuiCanvas = GuiBase.derive("GuiCanvas")
local scene         = import_package "ant.scene".util
local ru = import_package "ant.render".util
--local map_imgui   = import_package "ant.editor".map_imgui

local dbgutil = import_package "ant.editor".debugutil

local DefaultFPS = 30

local EditorProtectFrame = 60

GuiCanvas.GuiName = "GuiCanvas"

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
    self.need_focus_next_frame = false
    self.pause_on_error = true
    self.is_pausing = false
    self:set_fps(DefaultFPS)
    self.gizmo_type = {"position","rotation","scale"}
    self.gizmo_select = {"position",width=50}
end

function GuiCanvas:set_fps(fps)
    assert(fps>0)
    self.fps = fps
    self.frame_time = 1/fps
    self.editor_frame = 0
end

function GuiCanvas:bind_world( world, world_update)
    self.world = world
    self.world_update = world_update

    self.next_frame_time = 0
    self.time_count = 0
    self.last_update = nil
    self.last_world_update_limit = nil
end

function GuiCanvas:on_close_click()
    --dont close
end

function GuiCanvas:before_update()
    windows.SetNextWindowSize(self.rect.w,self.rect.h, "f")
    windows.PushStyleVar(enum.StyleVar.WindowPadding,0,0)
    if self.need_focus_next_frame  then
        windows.SetNextWindowFocus()
        self.need_focus_next_frame = false
    end
end

function GuiCanvas:_update_title_btns()
    windows.PushStyleVar(enum.StyleVar.SelectableTextAlign,0.5,0.5)
    for i,str in ipairs(self.gizmo_type) do
        local change = widget.Selectable(str,self.gizmo_select,str=="rotation")
        cursor.SameLine()
        if change then
            hub.publish(Event.GizmoType,self.gizmo_select[1])
        end
    end
    windows.PopStyleVar()
    local btn_name = self.is_pausing and "Run###Pause" or "Pause###Pause"
    if widget.Button(btn_name) then
        self.is_pausing = not self.is_pausing
    end
    cursor.SameLine()
    local change
    change,self.pause_on_error = widget.Checkbox("PauseOnError",self.pause_on_error)
    if change then
        self:mark_setting_dirty()
    end
end

local focus_flag = flags.Focused {"ChildWindows"}
function GuiCanvas:on_update(delta)
    self.editor_frame = self.editor_frame + 1
    self:_update_title_btns()
    local w,h = windows.GetContentRegionAvail()
    local x,y = cursor.GetCursorScreenPos()
    local r = self.rect
    if w~=r.w or h~=r.h or x~=r.x or y ~= r.y then
        self.vp_dirty = self.vp_dirty or (w~=r.w) or (h~=r.h)
        -- if  (w~=r.w) or (h~=r.h) then
        --     log.trace(">>>>>>",w,r.w,h,r.h)
        -- end
        self.rect = {x=x,y=y,w=w,h=h}
    end
    if self.world then
        local world_tex =  ru.get_main_view_rendertexture(self.world)
        if world_tex then
            widget.ImageButton(world_tex,w,h,{frame_padding=0,bg_col={0,0,0,1}})
        end
    end
    if not self.is_pausing then
        if IO.WantCaptureMouse then
            --todo:split mouse and keyboard
            self:on_dispatch_msg()
        end
        if self.world_update then
            self:_update_world(delta)
        end
    end
end

function GuiCanvas:_update_world(delta)
    local now = self.time_count + delta
    self.time_count = now
    if now >= self.next_frame_time then
        local can_update = true
        if self.last_world_update_limit then
            can_update = false
            if now > self.last_world_update_limit then
                can_update = true
            else
                local cur_editor_fps = self.editor_frame/(now - self.last_update)
                if cur_editor_fps >= EditorProtectFrame then
                    can_update = true
                end
            end
        end
        if can_update then
            if self.last_update then
                self.cur_frame_time = now - self.last_update
            end
            self.next_frame_time = now + self.frame_time
            self.last_update = now
            --update world
            local now_clock = os.clock()
            local success = dbgutil.try(self.world_update)
            if not success and self.pause_on_error then
                self.is_pausing = true
            end
            self.scene_cost = os.clock() - now_clock
            self.editor_frame = 0
            self.last_world_update_limit = 1.2 * math.min(self.scene_cost,1) + self.last_update
        end

    end

end

function GuiCanvas:on_dispatch_msg()
    --todo:split mouse and keyboard``
    if self.world == nil then
        return
    end

    local gui_input = gui_input
    local in_mouse  = gui_input.mouse_state
    local in_key    = gui_input.key_state
    local key_down  = gui_input.key_down
    local called    = gui_input.called
    local rect      = self.rect
    local rx, ry = 0, 0
    if in_mouse.x then
        rx,ry = in_mouse.x - rect.x,in_mouse.y - rect.y
    end
    local focus = windows.IsWindowFocused(focus_flag)
    local hovered = windows.IsWindowHovered(focus_flag)

    local msgqueue = self.world.args.mq

    if focus or ( hovered and self:check_is_click_inside(rx,ry)) then
        if not focus then
            self.need_focus_next_frame = true
        end
        local num_mouse_btn = 3
        for what=1, num_mouse_btn do
            if called[what] then
                local state = in_mouse[what]
                local btn = inputmgr.translate_mouse_button(what)
                local state = inputmgr.translate_mouse_state(state)
                if not self:check_is_left_click_outside(btn,state,rx,ry) then
                    msgqueue:push("mouse", rx, ry,
                    btn,
                    state)
                end
            end
        end
    end
    
    if hovered and called.mouse_wheel then
        msgqueue:push("mouse_wheel", rx, ry, in_mouse.scroll)
    end
    
    if focus and #key_down > 0 then
        for _,record in ipairs(key_down) do
            msgqueue:push("keyboard", inputmgr.translate_key(record[1]), record[2], in_key)
        end
    end
    local mouse_pressed =  gui_input.is_mouse_pressed(gui_input.MouseLeft)
    if not mouse_pressed and self.vp_dirty then
        self.vp_dirty = false
        msgqueue:push("resize", rect.w, rect.h)
    end
end

function GuiCanvas:check_is_click_inside(rx,ry)
    local gui_input = gui_input
    local called    = gui_input.called
    local in_mouse  = gui_input.mouse_state
    local rect = self.rect
    local num_mouse_btn = 3
    for what=1, num_mouse_btn do
        if called[what] then
            local state = in_mouse[what]
            state = inputmgr.translate_mouse_state(state)
            if state == "DOWN" then
                if rx >= 0 and rx <= rect.w then
                    if ry >= 0 and ry <= rect.h then
                        return true
                    end
                end
            end
        end
    end
end


function GuiCanvas:check_is_left_click_outside(btn,state,rx,ry)
    local rect = self.rect
    if btn == "LEFT" and state == "DOWN" then
        if rx >= 0 and rx <= rect.w then
            if ry >= 0 and ry <= rect.h then
                return false
            end
        end
        return true
    end
    return false
end


function GuiCanvas:after_update()
    windows.PopStyleVar()
end

----setting 
function GuiCanvas:mark_setting_dirty()
    self._dirty_flag = true
end

--override if needed
function GuiCanvas:is_setting_dirty()
    return self._dirty_flag
end

--override if needed
--return tbl
function GuiCanvas:save_setting_to_memory(clear_dirty_flag)
    if clear_dirty_flag then
        self._dirty_flag = false
    end
    return {
        pause_on_error = self.pause_on_error
    }
end

--override if needed
function GuiCanvas:load_setting_from_memory(setting_tbl)
    self.pause_on_error = setting_tbl.pause_on_error or true
end


return GuiCanvas
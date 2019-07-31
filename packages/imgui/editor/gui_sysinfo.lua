local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local gui_input = require "gui_input"
local bgfx      = require "bgfx"
local gui_mgr      = require "gui_mgr"

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
    self.status_open = true
    self._setting_dirty = false
    self._dirty_flag = false
    self.statistics = {}
end

function GuiSysInfo:before_open()
    self.frame_count = 0
    self.frame_time_count = 0
    self.fps = 0
    self.ft = 0
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
    if self.status_open then
        windows.SetNextWindowBgAlpha(0.75)
    else
        windows.SetNextWindowBgAlpha(0.35)
    end
    windows.SetNextWindowPos( winpos[1],winpos[2],nil,povit[1],povit[2] )
end

local btns = {"Custom","Top-left","Top-right","Bottom-left","Bottom-right"}

function GuiSysInfo:on_update(deltatime)
    self:update_fps(deltatime)
    local corner = self.corner
    if windows.BeginPopupContextWindow() then
        for i = -1,3 do
            local btn_str = btns[i+2]
            if widget.MenuItem(btn_str,nil,nil,corner ~= i) then
                corner = i
            end
        end
        if corner ~= self.corner then
            self.corner = corner
            self._dirty_flag = true
        end

        if widget.MenuItem("close") then
            self:on_close_click()
        end
        windows.EndPopup()
    end
end

local function memory_info()
    local memstat = bgfx.get_stats("m")
    local s = {"memory:"}
    local keys = {}
    for k in pairs(memstat) do
        keys[#keys+1] = k
    end
    table.sort(keys, function(lhs, rhs) return lhs < rhs end)
    for _, k in ipairs(keys) do
        local v = memstat[k]
        s[#s+1] = "\t" .. k .. ":" .. v
    end

    return table.concat(s, "\n")
end

function GuiSysInfo:update_fps(deltatime)
    self.frame_count = self.frame_count + 1
    self.frame_time_count = self.frame_time_count + deltatime
    if self.frame_count >= 1 and self.frame_time_count >= 1.0 then
        self.fps = self.frame_count/self.frame_time_count
        self.ft = 1/self.fps
        self.frame_count = 0
        self.frame_time_count = 0
        --
        local time_counts = gui_mgr.time_stack:get_time_list("k")
        local total_time = 0
        for _,data in ipairs(time_counts) do
            total_time = total_time + data[2]
        end
        self.statistics = {}
        for _,data in ipairs(time_counts) do
            local precent = data[2]/total_time
            local s = string.format("%s:%.2f%%",data[1],100*precent)
            table.insert(self.statistics,{precent,s})
        end
        gui_mgr.reset_time_count()
    end
    local fps_str = string.format("fps:%g###TreeHeader",self.fps)
    widget.SetNextItemOpen(self.status_open)
    if widget.TreeNode(fps_str) then
        self:set_status_open(true)
        widget.Text( string.format("frame time:%.3g",self.ft) )
        widget.Text( memory_info() )
            
        local mouse_state = gui_input.mouse_state
        local delta = mouse_state.delta
        widget.Text( string.format("mouse pos:%d/%d delta:%d/%d",mouse_state.x,mouse_state.y,delta.x,delta.y) )
        for _,v in ipairs(self.statistics) do
            widget.ProgressBar(v[1],v[2])
        end
        widget.TreePop()
    else
        self:set_status_open(false)
    end
end

function GuiSysInfo:set_status_open(value)
    if self.status_open~= value then
        self.status_open= value
        self._setting_dirty = true
    end
end

function GuiSysInfo:is_setting_dirty()
    return self._setting_dirty
end

function GuiSysInfo:load_setting_from_memory(setting)
    if setting.status_open ~= nil then
        self.status_open = setting.status_open
    end
    if setting.corner ~= nil then
        self.corner = setting.corner
    end
end

function GuiSysInfo:save_setting_to_memory(clear_dirty_flag)
    if clear_dirty_flag then
        self._setting_dirty = false
    end
    return {
        status_open = self.status_open,
        corner = self.corner,
    }
end


return GuiSysInfo
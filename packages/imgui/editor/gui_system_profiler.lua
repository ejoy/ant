local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local gui_mgr      = require "gui_mgr"
local hub       = import_package "ant.editor".hub
local Event = require "hub_event"

local GuiBase = require "gui_base"
local GuiSystemProfiler = GuiBase.derive("GuiSystemProfiler")

GuiSystemProfiler.GuiName = "GuiSystemProfiler"

function GuiSystemProfiler:_init()
    GuiBase._init(self)
    self.title = "GuiSystemProfiler"
    self.title_id = string.format("SystemProfiler###%s",self.GuiName)
    self.win_flags = flags.Window {  }
    self._is_opened = true
    self._last_records = {}
    self._status = "second" --"second"/"start","end"
    self._data_cache = {}
    self._data_show = nil
    self._time_count = 0
    self:_init_subcribe()
    self.sort_type = {selected="Cost","Cost","Name"}
end

function GuiSystemProfiler:_init_subcribe()
    hub.subscribe(Event.SystemProfile,self._on_system_profile,self)
end


--records:{{sys,what,"begin/end",time_ms},...}
function GuiSystemProfiler:_on_system_profile(records)
    self._last_records = records
end

function GuiSystemProfiler:_merge_cache()
    local cache = self._data_cache
    self._data_show = self._data_show or {}
    local data_show = self._data_show
    for k,v in pairs(cache) do
        if k ~= "cache" then
            data_show[k] = data_show[k] or {}
            local data_show_sys = data_show[k]
            for w,wv in pairs(v) do
                if k == 1 then
                    data_show_sys[1] = (data_show_sys[1] or 0 ) + wv
                else
                    data_show_sys[w] = (data_show_sys[w] or 0) + wv
                end
            end
        end
    end
    data_show.cache = nil
    self._data_cache = {}
end

function GuiSystemProfiler:on_update(delta)
    if self._status ~= "end" then
        self._time_count = self._time_count + delta
        if self._time_count >= 1 then
            if self._status == "second" then
                self._data_show = self._data_cache
                self._data_cache = {}
            else -- start
                self:_merge_cache()
            end
            self._time_count = 0
        end
        self:_process_record()
    end

    --ui
    -------control
    windows.PushStyleVar(enum.StyleVar.SelectableTextAlign,0.5,0.5)
    if widget.Selectable("Every Second",self._status == "second",100) then
        self._status =  "second"
        self._time_count = 0
        self._data_cache = {}
        self._data_show = nil
    end
    cursor.SameLine()
    if widget.Selectable("Start Record",self._status == "start",100) then
        self._status =  "start"
        self._data_cache = {}
        self._data_show = nil
        self._time_count = 0
    end
    cursor.SameLine()
    if widget.Selectable("End Record",self._status == "end",100) then
        self._status =  "end"
    end
    windows.PopStyleVar()
    ---------sort type
    cursor.SameLine()
    widget.Text("SortBy:")
    for i,v in ipairs(self.sort_type) do
        cursor.SameLine()
        if widget.RadioButton(v,v == self.sort_type.selected) then
            self.sort_type.selected = v
            local data = self._data_show or self._data_cache
            if data.cache then
                self:_refresh_sort_key(data)
            end
        end
    end
    self:_update_tree(self._data_show or self._data_cache)
end

function GuiSystemProfiler:_process_record()
    local last_records = self._last_records
    if last_records then
        local record = last_records
        local stack = {}
        local stack_size = 0
        for _,r in ipairs(record) do
            local sys,what,t,time_ms = table.unpack(r)
            local sys_dic = self._data_cache[sys] or {0}
            self._data_cache[sys] = sys_dic
            if t == "begin" then
                stack_size = stack_size + 1
                stack[stack_size] = time_ms
            else
                local start_t = stack[stack_size]
                local delta = time_ms - start_t
                stack_size = stack_size - 1
                sys_dic[1] =  sys_dic[1] + delta
                local sys_dic_what_cost = sys_dic[what] or 0
                sys_dic[what] = sys_dic_what_cost + delta
            end
        end
        self._data_cache.cache = nil
        assert(stack_size == 0,"time profile record error,begin/end not match!")
        self._last_records = nil
    end
end

function GuiSystemProfiler:_update_tree(data)
    if not data then return end
    if not data.cache then
        self:_sort_data(data)
    end
    local cache = data.cache
    assert(data.cache)
    local sort_key = cache.sort_key
    local precent = cache.precent
    local show_text = cache.show_text
    for _,sys in ipairs(sort_key) do
        local open = widget.TreeNode(string.format("###%s",sys))
        cursor.SameLine()
        widget.ProgressBar(precent[sys],show_text[sys])
        if open then
            local sys_data = data[sys]
            local sum = sys_data[1]
            for func,cost in pairs(sys_data) do
                if func ~= 1 then
                    widget.BulletText(string.format("%s:%.2fms %.2f%%",func,cost,cost/sum*100))
                end
            end
            widget.TreePop()
        end
    end

end

function GuiSystemProfiler:_refresh_sort_key(data)
    local sort_type = self.sort_type.selected
    local sort_key = {}
    local precent =  data.cache.precent
    for k,v in pairs(data) do
        if k ~= "cache" then
            table.insert(sort_key,k)
        end
    end
    if sort_type == "Cost" then
        table.sort(sort_key,function(a,b)
            return precent[a]>precent[b]
        end)
    else
        table.sort(sort_key)
    end
    data.cache.sort_key = sort_key
end

function GuiSystemProfiler:_sort_data(data)
    local sum  = 0
    local precent = {}
    local show_text = {}
    for k,v in pairs(data) do
        sum = sum + v[1]
    end

    for k,v in pairs(data) do
        precent[k] = (v[1]/sum)
        show_text[k] = string.format("%s:%.2f%%",k,precent[k]*100)
    end
    
    local cache = {
        precent = precent,
        sum = sum,
        show_text = show_text,
    }
    data.cache = cache
    self:_refresh_sort_key(data)
end

return GuiSystemProfiler
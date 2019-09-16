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
    self._data_cache = {0,children={}}
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
    self._data_show = self._data_show or {0,children={}}
    local data_show = self._data_show
    local function merge_children(src,dst)
        for k,v in pairs(src) do
            dst[k] = dst[k] or {0,0,children={}}
            local vd = dst[k]
            vd[1] = vd[1] + v[1]
            vd[2] = vd[2] + v[2]
            merge_children(v.children,vd.children)
        end
    end

    data_show[1] = cache[1] + data_show[1]

    merge_children(cache.children,data_show.children)
    data_show.cache = nil
    self._data_cache = {0,children={}}
end

function GuiSystemProfiler:on_update(delta)
    if self._status ~= "end" then
        self._time_count = self._time_count + delta
        if self._time_count >= 1 then
            if self._status == "second" then
                self._data_show = self._data_cache
                self._data_cache = {0,children={}}
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
        self._data_cache = {0,children={}}
        self._data_show = nil
    end
    cursor.SameLine()
    if widget.Selectable("Start Record",self._status == "start",100) then
        self._status =  "start"
        self._data_cache = {0,children={}}
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
        self._data_cache[1] = (self._data_cache[1] or 0 )+1
        local record = last_records
        local stack = {}
        local stack_size = 0
        self._data_cache.children = self._data_cache.children or {}
        local root_children = self._data_cache.children
        local record_index = 1
        local function process_func(top_sys,parent_tbl,children_tbl)
            local sys,what,begin_t,begin_time = table.unpack(record[record_index])
            if begin_t == "end" then
                return false
            end
            local name = nil
            if sys ~= top_sys then
                name = string.format("[%s].<%s>",sys,what)
            else
                name = string.format("<%s>",what)
            end
            local my_tbl = children_tbl[name] or {0,0,children={}}
            children_tbl[name] = my_tbl
            record_index = record_index + 1
            while process_func(top_sys,my_tbl,my_tbl.children) do
                --
            end
            local end_record = record[record_index]
            local _,_,end_t,end_time = table.unpack(end_record)
            assert(end_t == "end")
            my_tbl[1] = my_tbl[1] + 1
            my_tbl[2] = my_tbl[2] + (end_time-begin_time)
            record_index = record_index + 1
            return end_time-begin_time
        end
        local sys_runed = {}
        while record_index <= #record do
            local sys,what,t,time_ms = table.unpack(record[record_index])
            local sys_dic = root_children[sys] or {0,0,children={}}
            if not sys_runed[sys] then
                sys_runed[sys] = true
                sys_dic[1] = sys_dic[1] + 1
            end
            root_children[sys] = sys_dic
            local cost_time = process_func(sys,sys_dic,sys_dic.children)
            sys_dic[2] = sys_dic[2] + cost_time
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
    local frame = data[1]
    local cache = data.cache
    assert(data.cache)
    local sort_key = cache.sort_key
    local precent = cache.precent
    local show_text = cache.show_text
    if frame and frame > 0 then
        widget.BulletText(string.format("sum=%.2fms avg=%.2fms rawfps=%.2f",cache.sum,cache.sum/frame,frame/cache.sum*1000))
    end
    local str_temp = "%s avg_cost=%.2fms call_time:%d precent(sys):%.2f%% precent(total):%.2f%%"
    local function show_children(sys_time,parent_name,tbl)
        local children = tbl.children
        widget.TreePush(parent_name)
        for k,v in pairs(children) do
            local call_time,time_count,sub_children = v[1],v[2],v.children
            local avg_cost = time_count/call_time
            local precent_sys = time_count/sys_time*100
            local precent_total = time_count/cache.sum*100
            widget.BulletText(string.format(str_temp,k,avg_cost,call_time,precent_sys,precent_total))
            show_children(sys_time,k,v)
        end
        widget.TreePop()
    end
    for _,sys in ipairs(sort_key) do
        local open = widget.TreeNode(string.format("###%s",sys))
        cursor.SameLine()
        widget.ProgressBar(precent[sys],show_text[sys])
        if open then
            widget.TreePop()
            local sys_data = data.children[sys]
            show_children(sys_data[2],sys,sys_data)
        end
    end

end

function GuiSystemProfiler:_refresh_sort_key(data)
    local sort_type = self.sort_type.selected
    local sort_key = {}
    local precent =  data.cache.precent
    for k,v in pairs(data.children) do
        if (k ~= "cache") and (k ~= 1) then
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
    for k,v in pairs(data.children) do
        sum = sum + v[2]
    end

    for k,v in pairs(data.children) do
        precent[k] = (v[2]/sum)
        show_text[k] = string.format("[%s]:%.2f%%",k,precent[k]*100)
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
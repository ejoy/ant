
local imgui             = require "imgui_wrap"
local widget            = imgui.widget
local flags             = imgui.flags
local windows           = imgui.windows
local util              = imgui.util
local cursor            = imgui.cursor
local enum              = imgui.enum
local IO                = imgui.IO

local gui_util          = require "editor.gui_util"

local ColumnsID = "PropertyValueColunms"

local cur_tbl = nil


local class     = require "common.class"
local InspectorBase   = class("InspectorBase")

local UnappliedTips = "Unapplied setting for %s,\nstill want to open other resource?"

function InspectorBase:_init()
    self.res_ext = "xxx"
    self.modified = false
    self.res_pkg_path = nil --file_pathobj or [pathstr]
    self.res_arg = nil
    self.display_type_map = { --some cache data
        boolean = self.show_cfg_of_boolean,
    }
    self.write_type_map = { --some cache data
        boolean = self.write_cfg_of_boolean,
    }
    self.ui_cache = {}
end

function InspectorBase:get_type()
    return self.res_ext
end

function InspectorBase:set_res(res_pkg_path,res_arg)
    assert(self.res_pkg_path == nil,"should call close first!")
    self.res_pkg_path = res_pkg_path
    self.res_arg = res_arg

    self:before_res_open()
end

function InspectorBase:before_res_open()

end

function InspectorBase:on_update()
    widget.Text("Not Implemented!")
    if self.res_pkg_path then
        widget.Text("Path:"..(self.res_pkg_path:string()))
    end
end

--if close successfully,call cb(true),otherwise call cb(false)
function InspectorBase:try_close_res(cb)
    local function message_cb(result_code)
        local should_close = (result_code == 1)
        if should_close then
            self:clear()
        end
        cb(should_close)
    end
    if self.modified then
        local arg = {
            msg = string.format(UnappliedTips,self.res_pkg_path:string()),
            btn1 = "Yes",
            btn2 = "No",
            title = "Alter",
            close_cb = message_cb,
        }
        gui_util.message(arg)
    else
        message_cb(1)
    end
end

function InspectorBase:clear()
    self.modified = false
    self.res_pkg_path = nil
    self.res_arg = nil
    self:clear_ui_cache()
end

function InspectorBase:clear_ui_cache()
    self.ui_cache = {}
end

function InspectorBase:_show_key_value(parent_tbl,key,typ,indent)
    indent = indent or 0
    cursor.Columns(2,"InspectorKV")
    widget.Text(key)
    cursor.NextColumn()
    cursor.SetNextItemWidth(-1)
    local change,new_v = widget.Checkbox("###"..key,parent_tbl[key])
    if change then
        parent_tbl[key] = v
    end
    cursor.Columns(1)
    return change,new_v
end

function InspectorBase:show_import_cfg(data,cfg)
    local change = false
    for _,cfg_item in ipairs(cfg) do
        change = self:show_one_cfg(data,cfg_item) or change
    end
    return change
end

function InspectorBase:show_one_cfg(data_tbl,cfg_item)
    local field = cfg_item.display or cfg_item.field
    local type_cfg_field = type(field)
    if type_cfg_field == "string" then
        local func = self.display_type_map[field]
        if not func then
            widget.Text("Unimplemented field type:",field)
        end
        return func(self,data_tbl,cfg_item)
    elseif type_cfg_field == "function" then
        local func = field
        return func(self,data_tbl,cfg_item)
    elseif type_cfg_field == "table" then
        local data = data_tbl[cfg_item.name]
        local change = false
        if widget.TreeNode(cfg_item.name,flags.TreeNode.DefaultOpen) then
            -- cursor.Indent()
            for _,citem in ipairs(field) do
                change = self:show_one_cfg(data,citem) or change
            end
            widget.TreePop()
        end
        -- cursor.Unindent()
        return change
    else
        widget.Text("Unknown field type:"..type_cfg_field)
    end

end

function InspectorBase:show_cfg_of_boolean(data_tbl,cfg)
    local field_name = cfg.name
    local value = data_tbl[field_name]
    local change = false
    self:BeginColunms()
    widget.Text(field_name)
    cursor.NextColumn()
    cursor.SetNextItemWidth(-1)
    change,value = widget.Checkbox("###"..field_name,value)
    data_tbl[field_name] = value
    self:EndColunms()
    return change
end

function InspectorBase:BeginProperty()
    assert(not cur_tbl,"Program Error")
    self.column_cache = self.column_cache or {}
    cur_tbl = self.column_cache
    cur_tbl.column2_last_change = cur_tbl.column2_last_change or false
    cur_tbl.column2_cur_change = false
end

function InspectorBase:EndProperty()
    cur_tbl.column2_last_change = cur_tbl.column2_cur_change
    cur_tbl = nil
end

function InspectorBase:BeginColunms()
    cursor.Columns(2,ColumnsID,true)
    windows.PushStyleColor(enum.StyleCol.Separator,1,1,1,0.01)
    if cur_tbl.column2_last_change then
        cursor.SetColumnOffset(2,cur_tbl.offset_2)
    end
end

function InspectorBase:EndColunms()
    if (not cur_tbl.column2_last_change) and (not cur_tbl.column2_cur_change) then
        local new_offset = cursor.GetColumnOffset(2)
        cur_tbl.column2_cur_change = cur_tbl.offset_2 and (new_offset ~= cur_tbl.offset_2)
        cur_tbl.offset_2 = new_offset
        cur_tbl.dirty = true
    end
    cursor.Columns(1)
    windows.PopStyleColor()
end

function InspectorBase:write_cfg(data,cfg,tbl,indent)
    for _,cfg_item in ipairs(cfg) do
        self:write_one_cfg(data,cfg_item,tbl,indent)
    end
end

function InspectorBase:write_one_cfg(data,cfg_item,tbl,indent)
    local name = cfg_item.name
    
    local cfg_field = cfg_item.write or cfg_item.field
    local type_cfg_field = type(cfg_field)
        
    if type_cfg_field == "string" then
        local func = self.write_type_map[cfg_field]
        if not func then
            log.info_a("Unimplemented field type:",cfg_field)
        else
            func(self,data,cfg_item,tbl,indent)
        end
    elseif type_cfg_field == "function" then
        local func = cfg_field
        func(self,data,cfg_item,tbl,indent)
    elseif type_cfg_field == "table" then
        local sub_data = data[cfg_item.name]
        table.insert(tbl,indent)
        table.insert(tbl,name)
        table.insert(tbl," = {\n")
        for _,citem in ipairs(cfg_item.field) do
            self:write_one_cfg(sub_data,citem,tbl,indent.."\t")
        end
        table.insert(tbl,indent)
        table.insert(tbl,"},\n")
    else
        table.insert(tbl,indent)
        table.insert(tbl,name)
        table.insert(tbl," = ")
        table.insert(tbl,"[Unknown field type:"..type_cfg_field.."]")
        table.insert(tbl,",\n")
    end
end

function InspectorBase:write_cfg_of_boolean(data,cfg_item,tbl,indent)
    local name = cfg_item.name
    local bool_val = data[name]
    if bool_val ~= nil then
        table.insert(tbl,indent)
        table.insert(tbl,name)
        table.insert(tbl," = ")
        table.insert(tbl,bool_val and "true" or "false")
        table.insert(tbl,",\n")
    end
end




return InspectorBase
local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local IO      = imgui.IO

local ColumnsID = "PropertyValueColunms"

local cur_tbl = nil

local function BeginProperty(tbl)
    assert(not cur_tbl,"Program Error")
    cur_tbl = tbl
    cur_tbl.column2_last_change = cur_tbl.column2_last_change or false
    cur_tbl.column2_cur_change = false
end

local function EndProperty()
    cur_tbl.column2_last_change = cur_tbl.column2_cur_change
    cur_tbl = nil
end

local function BeginColunms()
    cursor.Columns(2,ColumnsID,true)
    windows.PushStyleColor(enum.StyleCol.Separator,1,1,1,0.01)
    if cur_tbl.column2_last_change then
        cursor.SetColumnOffset(2,cur_tbl.offset_2)
    end
end

local function EndColunms()
    if (not cur_tbl.column2_last_change) and (not cur_tbl.column2_cur_change) then
        local new_offset = cursor.GetColumnOffset(2)
        cur_tbl.column2_cur_change = cur_tbl.offset_2 and (new_offset ~= cur_tbl.offset_2)
        cur_tbl.offset_2 = new_offset
        cur_tbl.dirty = true
    end
    cursor.Columns(1)
    windows.PopStyleColor()
end

local function real(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {value}
        ui_cache[name] = vt
    end
    BeginColunms()
    widget.Text(name)
    cursor.NextColumn()
    cursor.SetNextItemWidth(-1)
    local change = widget.DragFloat("###"..name,vt)
    EndColunms()
    return change,vt[1]
end

local function boolean(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {value}
        ui_cache[name] = vt
    end
    BeginColunms()
    widget.Text(name)
    cursor.NextColumn()
    cursor.SetNextItemWidth(-1)
    local change = widget.Checkbox("###"..name, vt)
    EndColunms()
    return change,vt[1]
end

local function string(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {text=value}
        ui_cache[name] = vt
    end
    BeginColunms()
    widget.Text(name)
    cursor.NextColumn()
    cursor.SetNextItemWidth(-1)
    local change = widget.InputText("###"..name, vt)
    EndColunms()
    return change,vt.text
end

local function int(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {value}
        ui_cache[name] = vt
    end
    BeginColunms()
    widget.Text(name)
    cursor.NextColumn()
    cursor.SetNextItemWidth(-1)
    local change = widget.DragInt("###"..name,vt)
    EndColunms()
    return change,vt[1]
end

local function vector(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {value[1],value[2],value[3],value[4]}
        ui_cache[name] = vt
    end
    BeginColunms()
    widget.Text(name)
    cursor.NextColumn()
    cursor.SetNextItemWidth(-1)
    local change = widget.DragFloat("###DragFloat"..name,vt)
    EndColunms()
    return change,{vt[1],vt[2],vt[3],vt[4]}
end

local function matrix(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {{},{},{},{}}
        ui_cache[name] = vt
        for i = 1,16 do
            vt[i//4+1][i%4] = value[i]
        end
    end
    BeginColunms()
    cursor.NextColumn()
    local change = false
    if widget.TreeNode(name) then
        for i = 1,4 do
            local this_vt = vt[i]
            if widget.DragFloat("###"..tostring(i),vt[i]) then
                change = true
                local start = i*4-4
                for j = 1,4 do
                    value[start+j] = this_vt[j]
                end
            end
        end
        widget.TreePop()
    end
    EndColunms()
    return change,value
end

local function entityid(ui_cache,name,value)
    --todo:use button to jump
    BeginColunms()
    widget.Text(name)
    cursor.NextColumn()
    cursor.SetNextItemWidth(-1)
    widget.Button(value)
    if util.IsItemHovered() then
        widget.SetTooltip("Jump to entity\nTo be implement...")
    end
    EndColunms()
    return false,value
end

local function primtype(ui_cache,name,value)
    BeginColunms()
    widget.Text(name)
    cursor.NextColumn()
    widget.Text(dump_a({value}))
    EndColunms()
    return false,value
end

return {
    real = real,
    boolean = boolean,
    string = string,
    int = int,
    vector = vector,
    uniformdata = vector,
    matrix = matrix,
    color = color,
    entityid = entityid,
    primtype = primtype,
    BeginProperty = BeginProperty,
    EndProperty = EndProperty,
}
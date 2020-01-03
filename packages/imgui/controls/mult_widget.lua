local imgui = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local class     = require "common.class"

local function compare(tbls)
    local v1 = tbls[1]
    for i = 2,#tbls do
        if tbls[i] ~= v1 then
            return false
        end
    end
    return true
end

local function get_title(title_id)
    local first_pos = string.find(title_id,"##")
    if first_pos then
        if first_pos>1 then
            return true,string.sub(title_id,1,first_pos-1)
        else
            return false
        end
    else
        return #title_id>0,title_id
    end
end

local function drag_mult(widget_func)
    return function(title_id,vals,arg_tbl)
        local is_same = compare(vals)
        arg_tbl[1] = vals[1]
        if is_same then
            if widget_func(title_id,arg_tbl) then
                for i = 1, #vals do
                    vals[i] = arg_tbl[1]
                end
                return true,arg_tbl[1]
            else
                return false
            end
        else
            windows.PushStyleColor(enum.StyleCol.FrameBg,0.7,0.7,0.7,0.5)
            local change = widget_func(title_id,arg_tbl)
            if util.IsItemHovered() then
                widget.BeginTooltip()
                widget.Text("Mult Values:")
                widget.Text("-----------------------")
                for i = 1,#vals do
                    widget.Text(string.format("\t%d:%s",i,tostring(vals[i])))
                end
                widget.EndTooltip()
            end
            windows.PopStyleColor()
            if change then
                for i = 1, #vals do
                    vals[i] = arg_tbl[1]
                end
                return true,vals[1]
            else
                return false
            end
        end
    end
end


local item_inner_spacing = 4.0

local function drag_vector(title_id,vals,arg_tbl)
    local vector_num = #vals --3
    local vector_length = #(vals[1]) --4
    local w = util.CalcItemWidth()
    -- print(w,cursor.GetCursorPos())
    local width = (w+item_inner_spacing) / vector_length - item_inner_spacing
    local has_change = false
    -- windows.PushStyleVar(enum.StyleVar.ItemSpacing,item_inner_spacing,item_inner_spacing)
    for i = 1,vector_length do

        local one_val = {}
        for j = 1,vector_num do
            one_val[j] = vals[j][i]
        end
        local is_same = compare(one_val)
        arg_tbl[1] = one_val[1]
        cursor.SetNextItemWidth(width)
        if is_same then
            if widget.DragFloat("##"..title_id..i,arg_tbl) then
                for j = 1,vector_num do
                    vals[j][i] = arg_tbl[1]
                end
                has_change = true
            end
        else
            windows.PushStyleColor(enum.StyleCol.FrameBg,0.7,0.7,0.7,0.5)
            local change = widget.DragFloat("##"..title_id..i,arg_tbl)
            if util.IsItemHovered() then
                widget.BeginTooltip()
                widget.Text("Mult Values:")
                widget.Text("-----------------------")
                for j = 1,vector_num do
                    widget.Text(string.format("\t%d:%s",j,tostring(one_val[j])))
                end
                widget.EndTooltip()
            end
            windows.PopStyleColor()
            if change then
                for j = 1,vector_num do
                    vals[j][i] = arg_tbl[1]
                end
                has_change = true
            end
        end
        cursor.SameLine(0,item_inner_spacing)
    end
    --title
    local has_title,display_title = get_title(title_id)
    if has_title then
        widget.Text(display_title)
    end
    -- windows.PopStyleVar()

    return has_change
end

-- local function checkbox(title_id,vals,arg_tbl)
--     local is_same = compare(vals)
--     arg_tbl[1] = vals[1]    
--     if is_same then
--         if widget_func(title_id,arg_tbl) then
--             for i = 1, #vals do
--                 vals[i] = arg_tbl[1]
--             end
--             return true,arg_tbl[1]
--         else
--             return false
--         end
--     else
--         windows.PushStyleColor(enum.StyleCol.FrameBg,0.7,0.7,0.7,0.5)
--         local change = widget_func(title_id,arg_tbl)
--         if util.IsItemHovered() then
--             widget.BeginTooltip()
--             widget.Text("Mult Values:")
--             widget.Text("-----------------------")
--             for i = 1,#vals do
--                 widget.Text(string.format("\t%d:%s",i,tostring(vals[i])))
--             end
--             widget.EndTooltip()
--         end
--         windows.PopStyleColor()
--         if change then
--             for i = 1, #vals do
--                 vals[i] = arg_tbl[1]
--             end
--             return true,vals[1]
--         else
--             return false
--         end
--     end
-- end
return {
    DragFloat = drag_mult(widget.DragFloat),
    DragInt = drag_mult(widget.DragInt),
    DragVector = drag_vector,
    InputText = drag_mult(widget.InputText),
    Checkbox = drag_mult(widget.Checkbox),
}
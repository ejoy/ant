local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local IO      = imgui.IO

local function real(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {value}
        ui_cache[name] = vt
    end
    widget.Text(name)
    cursor.SameLine()
    cursor.SetNextItemWidth(-1)
    if widget.DragFloat("###"..name,vt) then
        return true,vt[1]
    end
end

local function boolean(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {value}
        ui_cache[name] = vt
    end
    widget.Text(name)
    cursor.SameLine()
    cursor.SetNextItemWidth(-1)
    if widget.Checkbox("###"..name, vt) then
        return true,vt[1]
    end
end

local function string(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {text=value}
        ui_cache[name] = vt
    end
    widget.Text(name)
    cursor.SameLine()
    cursor.SetNextItemWidth(-1)
    if widget.InputText("###"..name, vt) then
        return true,vt.text
    end
end

local function int(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {value}
        ui_cache[name] = vt
    end
    widget.Text(name)
    cursor.SameLine()
    cursor.SetNextItemWidth(-1)
    if widget.DragInt("###"..name,vt) then
        return true,vt[1]
    end
end

local function vector(ui_cache,name,value)
    local vt = ui_cache[name]
    if not vt then
        vt = {value[1],value[2],value[3],value[4]}
        ui_cache[name] = vt
    end
    widget.Text(name)
    cursor.SameLine()
    cursor.SetNextItemWidth(-1)
    if widget.DragFloat("###"..name,vt) then
        return true,{vt[1],vt[2],vt[3],vt[4]}
    end
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
    if widget.TreeNode(name) then
        local change = false
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
        return change,value
    end
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
}
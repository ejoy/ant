local imgui      = require "imgui"

local compdefines=require "widget.component_defines"

local SameLine = imgui.cursor.SameLine()
local PropertyLabel = imgui.widget.PropertyLabel
local Text          = imgui.widget.Text
local DisableText   = imgui.widget.DisableText
local InputText     = imgui.widget.InputText
local InputInt      = imgui.widget.InputInt
local InputFloat    = imgui.widget.InputFloat
local Checkbox      = imgui.widget.Checkbox
local ColorEdit     = imgui.widget.ColorEdit
local Combo         = imgui.widget.Combo
local BeginDisabled = imgui.windows.BeginDisabled
local EndDisabled   = imgui.windows.EndDisabled


local function int_widget(name, comp, desc, updatevalue)
    PropertyLabel(name)
    BeginDisabled(desc.readonly)
    
    local value = {comp}
    if InputInt("##" .. name, value) then
        updatevalue[name] = value[1]
    end
    EndDisabled()
end

local function float_widget(name, comp, desc,  updatevalue)
    PropertyLabel(name)
    BeginDisabled(desc.readonly)
    local value = {comp}
    if InputFloat("##" .. name, value) then
        updatevalue[name] = value[1]
    end
    EndDisabled()
end

local function vec_widget(name, comp, desc, n, vectype, updatevalue)
    PropertyLabel(name)
    BeginDisabled(desc.readonly)
    assert(type(comp) == "table")
    local value = {table.unpack(comp)}
    value[n+1] = nil

    local inputwidget
    if vectype == "int" then
        inputwidget = InputInt
    elseif vectype == "float" then
        inputwidget = InputFloat
    else
        error(("component name: %s, invalid vec type:%s"):format(name, vectype))
    end

    if inputwidget("##" .. name, value) then
        updatevalue[name] = value
    end
    EndDisabled()
end

local component_type_registers = {
    string = function (name, comp, desc, updatevalue)
        PropertyLabel(name)
        BeginDisabled(desc.readonly)
        local value = {text=comp or ""}
        if InputText("##" .. name, value) then
            updatevalue[name] = tostring(value.text)
        end
        EndDisabled()
    end,
    int = int_widget,
    ivec1 = int_widget,
    float = float_widget,
    bool = function (name, comp, desc, updatevalue)
        PropertyLabel(name)
        imgui.windows.BeginDisabled(desc.readonly)
        local value = {comp}
        if Checkbox("##" .. name, value) then
            updatevalue[name] = value[1]
        end
        
        imgui.windows.EndDisabled()
    end,
    vec2 = function (name, comp, desc,  updatevalue)
        vec_widget(name, comp, desc, 2, "float", updatevalue)
    end,
    vec3 = function (name, comp, desc, updatevalue)
        vec_widget(name, comp, desc, 3, "float", updatevalue)
    end,
    vec4 = function (name, comp, desc, updatevalue)
        vec_widget(name, comp, desc, 4, "float", updatevalue)
    end,
    ivec2 = function (name, comp, desc, updatevalue)
        vec_widget(name, comp, desc, 2, "int", updatevalue)
    end,
    ivec3 = function (name, comp, desc, updatevalue)
        vec_widget(name, comp, desc, 3, "int", updatevalue)
    end,
    ivec4 = function (name, comp, desc, updatevalue)
        vec_widget(name, comp, desc, 4, "int", updatevalue)
    end,
    color = function (name, comp, desc, updatevalue)
        PropertyLabel(name)
        BeginDisabled(desc.readonly)
        assert(type(comp) == "table" and #comp == 4)
        local value = {table.unpack(comp)}
        if ColorEdit("##" .. name, value) then
            updatevalue[name] = value
        end
        EndDisabled()
    end
}

local function build_entity_ui(name, comp, cdesc, updatevalue)
    local function check_desc(d)
        return d
    end

    local d = check_desc(cdesc)
    local comptype = d.type
    if comptype == nil then
        assert(type(comp) == "table")
        if imgui.widget.TreeNode(name, imgui.flags.TreeNode { "DefaultOpen" }) then
            for k, v in compdefines.sort_pairs(comp) do
                local dd = d[k]
                assert(dd, ("component is not define in desc file:%s"):format(k))
                local vv = {}
                build_entity_ui(k, v, dd, vv)
                if next(vv) then
                    updatevalue[k] = vv
                end
            end
            imgui.widget.TreePop()
        end
    else
        local w = assert(component_type_registers[comptype])
        w(name, comp, d, updatevalue)
    end
end

return {
    build = build_entity_ui,
    register = function (comptype, widget_creator)
        assert(component_type_registers[comptype], ("duplicate component type:%s"):format(comptype))
        component_type_registers[comptype] = widget_creator
    end
}
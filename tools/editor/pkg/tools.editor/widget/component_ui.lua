local ImGui      = import_package "ant.imgui"

local compdefines=require "widget.component_defines"

local SameLine = ImGui.SameLine()
local PropertyLabel = ImGui.PropertyLabel
local Text          = ImGui.Text
local DisableText   = ImGui.DisableText
local InputText     = ImGui.InputText
local InputInt      = ImGui.InputInt
local InputFloat    = ImGui.InputFloat
local Checkbox      = ImGui.Checkbox
local ColorEdit     = ImGui.ColorEdit
local BeginCombo    = ImGui.BeginCombo
local Selectable    = ImGui.Selectable
local EndCombo      = ImGui.EndCombo
local BeginDisabled = ImGui.BeginDisabled
local EndDisabled   = ImGui.EndDisabled

local function find_widget(wname)
    return assert(ImGui[wname])
end

local function list_combo(name, comp, ll, updatevalue)
    if BeginCombo("##" .. name, {comp}) then
        for ii=1, #ll do
            local v = ll[ii]
            if Selectable(v, v == name) then
                updatevalue[name] = v
            end
        end
        EndCombo()
    end
end

local function int_widget(name, comp, desc, updatevalue)
    PropertyLabel(name)
    BeginDisabled(desc.readonly)

    local ll = desc.list
    if ll then
        list_combo(name, comp, ll, updatevalue)
    else
        local value = {comp}
        local w = desc.widget and find_widget(desc.widget) or InputInt
        if w("##" .. name, value) then
            updatevalue[name] = value[1]
        end
    end
    EndDisabled()
end

local function float_widget(name, comp, desc, updatevalue)
    PropertyLabel(name)
    BeginDisabled(desc.readonly)

    local ll = desc.list
    if ll then
        list_combo(name, comp, ll, updatevalue)
    else
        local value = {comp}
        local w = desc.widget and find_widget(desc.widget) or InputFloat
        if w("##" .. name, value) then
            updatevalue[name] = value[1]
        end
    end
    EndDisabled()
end

local function string_widget(name, comp, desc, updatevalue)
    PropertyLabel(name)
    BeginDisabled(desc.readonly)
    local ll = desc.list
    if ll then
        list_combo(name, comp, ll, updatevalue)
    else
        local value = {text=comp or ""}
        if InputText("##" .. name, value) then
            updatevalue[name] = tostring(value.text)
        end
    end
    EndDisabled()
end

local function find_input_widget(t)
    if t == "int" then
        return InputInt
    elseif t == "float" then
        return InputFloat
    elseif t == "string" then
        return InputText
    else
        error("input type:" .. t)
    end
end

local function vec_widget(name, comp, desc, n, vectype, updatevalue)
    PropertyLabel(name)
    BeginDisabled(desc.readonly)
    assert(type(comp) == "table")
    local value = {table.unpack(comp)}
    value[n+1] = nil

    local inputwidget = desc.widget and find_widget(desc.widget) or find_input_widget(vectype)

    if inputwidget("##" .. name, value) then
        updatevalue[name] = value
    end
    EndDisabled()
end

local component_type_registers = {
    string = string_widget,
    int = int_widget,
    ivec1 = int_widget,
    float = float_widget,
    vec1 = float_widget,
    bool = function (name, comp, desc, updatevalue)
        PropertyLabel(name)
        ImGui.BeginDisabled(desc.readonly)
        local value = {comp}
        if Checkbox("##" .. name, value) then
            updatevalue[name] = value[1]
        end

        ImGui.EndDisabled()
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
    end,
}

local function build_entity_ui(name, comp, cdesc, updatevalue)
    local function check_desc(d)
        return d
    end

    local d = check_desc(cdesc)
    local comptype = d.type
    if comptype == nil then
        assert(type(comp) == "table")
        if ImGui.TreeNode(name, ImGui.Flags.TreeNode { "DefaultOpen" }) then
            local vv = {}
            for k, v in compdefines.sort_pairs(comp) do
                local dd = d[k] or error (
					("component is not define in desc file:%s"):format(k))
                build_entity_ui(k, v, dd, vv)
            end
            if next(vv) then
                updatevalue[name] = vv
            end
            ImGui.TreePop()
        end
    else
        local w = assert(component_type_registers[comptype])
        w(name, comp, d, updatevalue)
    end
end

return {
    build = build_entity_ui,
    register = function (comptype, widget_creator)
        local _ = component_type_registers[comptype] or error (("duplicate component type:%s"):format(comptype))
        component_type_registers[comptype] = widget_creator
    end
}